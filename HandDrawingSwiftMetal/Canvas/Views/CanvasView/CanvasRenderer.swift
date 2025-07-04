//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit

/// A class that renders textures from `TextureRepository` onto the canvas
final class CanvasRenderer: ObservableObject {

    var frameSize: CGSize = .zero

    var matrix: CGAffineTransform = .identity

    private let renderer: MTLRendering!

    private var textureRepository: TextureRepository?

    /// The texture that combines the background color and the textures of `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`
    private(set) var canvasTexture: MTLTexture?

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture!

    /// The texture of the selected layer.
    private(set) var selectedTexture: MTLTexture!

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.renderer = renderer
    }

    func initTextures(textureSize: CGSize) {
        guard
            Int(textureSize.width) >= MTLRenderer.threadGroupLength &&
            Int(textureSize.height) >= MTLRenderer.threadGroupLength
        else {
            assert(false, "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return
        }

        guard
            let unselectedBottomTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let selectedTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let unselectedTopTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let canvasTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.unselectedBottomTexture = unselectedBottomTexture
        self.selectedTexture = selectedTexture
        self.unselectedTopTexture = unselectedTopTexture
        self.canvasTexture = canvasTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.selectedTexture?.label = "selectedTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"
        self.canvasTexture?.label = "canvasTexture"
    }

    func setTextureRepository(_ textureRepository: TextureRepository) {
        self.textureRepository = textureRepository
    }

}

extension CanvasRenderer {
    func bottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    func topLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    /// Updates `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`.
    /// This textures are pre-merged from `textureRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    func updateDrawingTextures(
        canvasState: CanvasState,
        with commandBuffer: MTLCommandBuffer,
        onCompleted: (() -> Void)?
    ) {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else {
            return
        }

        // The selected texture is kept opaque here because transparency is applied when used
        var opaqueLayer = selectedLayer
        opaqueLayer.alpha = 255

        let bottomPublisher = drawLayerTextures(
            layers: bottomLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            on: unselectedBottomTexture,
            with: commandBuffer
        )

        let topPublisher = drawLayerTextures(
            layers: topLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            on: unselectedTopTexture,
            with: commandBuffer
        )

        let selectedPublisher = drawLayerTextures(
            layers: [opaqueLayer],
            on: selectedTexture,
            with: commandBuffer
        )

        Publishers.CombineLatest3(
            bottomPublisher,
            selectedPublisher,
            topPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { _ in
                onCompleted?()
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    }

    /// Updates the canvas using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    func updateCanvasView(
        _ canvasView: CanvasViewProtocol?,
        realtimeDrawingTexture: MTLTexture? = nil,
        selectedLayer: TextureLayerModel,
        backgroundColor: UIColor = .white,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let canvasTexture else { return }

        renderer.fillTexture(
            texture: canvasTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: unselectedBottomTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        if selectedLayer.isVisible {
            renderer.mergeTexture(
                texture: realtimeDrawingTexture ?? selectedTexture,
                alpha: selectedLayer.alpha,
                into: canvasTexture,
                with: commandBuffer
            )
        }

        renderer.mergeTexture(
            texture: unselectedTopTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        updateCanvasView(canvasView, with: commandBuffer)
    }

    func updateCanvasView(_ canvasView: CanvasViewProtocol?, with commandBuffer: MTLCommandBuffer) {
        guard let renderTexture = canvasView?.renderTexture else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: UIColor(rgb: Constants.blankAreaBackgroundColor),
            on: renderTexture,
            device: device,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

    func drawLayerTextures(
        layers: [TextureLayerModel],
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.failedToUnwrap).eraseToAnyPublisher()
        }

        // Clear the destination texture before merging
        renderer.clearTexture(texture: destinationTexture, with: commandBuffer)

        // If no layers, return immediately as success
        guard !layers.isEmpty else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        // Copy textures from the repository
        return textureRepository.copyTextures(
            uuids: layers.map { $0.id }
        )
        .map { [weak self] results in
            for layer in layers {
                // Convert entities to a dictionary for easy lookup
                let textureDict = Dictionary(uniqueKeysWithValues: results.map { ($0.uuid, $0.texture) })

                if let resultTexture = textureDict[layer.id]?.flatMap({ $0 }) {
                    self?.renderer.mergeTexture(
                        texture: resultTexture,
                        alpha: layer.alpha,
                        into: destinationTexture,
                        with: commandBuffer
                    )
                }
            }
            return ()
        }
        .eraseToAnyPublisher()
    }

}
