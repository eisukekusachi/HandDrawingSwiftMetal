//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import MetalKit
import Combine

final class CanvasRenderer: ObservableObject {

    var backgroundColor: UIColor = .white

    var frameSize: CGSize = .zero

    var matrix: CGAffineTransform = .identity

    var hasTextureBeenInitialized: Bool {
        textureSize != .zero
    }

    var commandBuffer: MTLCommandBuffer? {
        canvasView?.commandBuffer
    }

    var renderTextureSize: CGSize? {
        canvasView?.renderTexture?.size
    }

    private(set) var textureSize: CGSize = .zero

    private var canvasView: CanvasViewProtocol?

    private let transformer = CanvasTransformer()

    /// The texture that combines the background color and the textures of all `TextureLayers`.
    private(set) var canvasTexture: MTLTexture?

    /// The texture of the selected layer.
    private(set) var selectedTexture: MTLTexture!

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture!

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private var textureRepository: TextureRepository?

    private let renderer: (any MTLRendering)!

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
            textureSize >= MTLRenderer.minimumTextureSize,
            let unselectedBottomTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let selectedTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let unselectedTopTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let canvasTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.textureSize = textureSize

        self.unselectedBottomTexture = unselectedBottomTexture
        self.selectedTexture = selectedTexture
        self.unselectedTopTexture = unselectedTopTexture
        self.canvasTexture = canvasTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.selectedTexture?.label = "selectedTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"
        self.canvasTexture?.label = "canvasTexture"
    }

    func setCanvas(_ canvasView: CanvasViewProtocol?) {
        self.canvasView = canvasView
    }

    func setTextureRepository(_ textureRepository: TextureRepository) {
        self.textureRepository = textureRepository
    }

    func resetCommandBuffer() {
        canvasView?.resetCommandBuffer()
    }

}

extension CanvasRenderer {
    func bottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    func topLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    /// Updates the drawing textures. This textures are pre-merged from layers necessary for drawing.
    /// By using this textures, the drawing performance remains consistent regardless of the number of layers.
    func updateDrawingTextures(
        canvasState: CanvasState,
        commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else {
            return Fail(error: TextureRepositoryError.failedToUnwrap).eraseToAnyPublisher()
        }

        // The selected texture is kept opaque here because transparency is applied when used
        var opaqueLayer = selectedLayer
        opaqueLayer.alpha = 255

        let bottomPublisher = renderTexturesFromRepositoryToTexturePublisher(
            layers: bottomLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            into: unselectedBottomTexture,
            with: commandBuffer
        )

        let topPublisher = renderTexturesFromRepositoryToTexturePublisher(
            layers: topLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            into: unselectedTopTexture,
            with: commandBuffer
        )

        let selectedPublisher = renderTexturesFromRepositoryToTexturePublisher(
            layers: [opaqueLayer],
            into: selectedTexture,
            with: commandBuffer
        )

        return Publishers.CombineLatest3(
            bottomPublisher,
            topPublisher,
            selectedPublisher
        )
        .map { _, _, _ in () }
        .eraseToAnyPublisher()
    }

    /// Draws `sourceTexture` on a copy of the target texture from the repository and returns the result
    func drawOnTextureFromRepository(
        sourceTexture: MTLTexture,
        targetTextureId: UUID
    ) -> AnyPublisher<MTLTexture, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.repositoryUnavailable).eraseToAnyPublisher()
        }

        return textureRepository.getTexture(
            uuid: targetTextureId,
            textureSize: sourceTexture.size
        )
        .flatMap { [weak self] targetTexture -> AnyPublisher<MTLTexture, Error> in
            guard
                let `self`,
                let targetTexture,
                let flippedTextureBuffers = self.flippedTextureBuffers,
                let temporaryRenderCommandBuffer = self.device.makeCommandQueue()?.makeCommandBuffer()
            else {
                return Fail(error: TextureRepositoryError.failedToUnwrap).eraseToAnyPublisher()
            }

            temporaryRenderCommandBuffer.label = "commandBuffer"

            self.renderer.drawTexture(
                texture: sourceTexture,
                buffers: flippedTextureBuffers,
                withBackgroundColor: .clear,
                on: targetTexture,
                with: temporaryRenderCommandBuffer
            )
            temporaryRenderCommandBuffer.commit()

            return Future { promise in
                temporaryRenderCommandBuffer.addCompletedHandler { _ in
                    promise(.success(targetTexture))
                }
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func renderTexturesFromRepositoryToTexturePublisher(
        layers: [TextureLayerModel],
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.repositoryUnavailable).eraseToAnyPublisher()
        }

        // Clear `destinationTexture` here
        renderer.clearTexture(texture: destinationTexture, with: commandBuffer)

        // Emit `Void` as a success value when the array is empty
        guard
            !layers.isEmpty
        else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return textureRepository.getTextures(
            uuids: layers.map { $0.id },
            textureSize: destinationTexture.size
        )
        .handleEvents(receiveOutput: { [weak self] textures in
            guard let `self` else { return }

            for layer in layers {
                if let resultTexture = textures[layer.id]?.flatMap({ $0 }) {
                    self.renderer.mergeTexture(
                        texture: resultTexture,
                        alpha: layer.alpha,
                        into: destinationTexture,
                        with: commandBuffer
                    )
                }
            }
        })
        .map { _ in () }
        .eraseToAnyPublisher()
    }

}

extension CanvasRenderer {
    /// Updates the canvas using `unselectedTopTexture` and `unselectedBottomTexture`
    func updateCanvasView(
        realtimeDrawingTexture: MTLTexture? = nil,
        selectedLayer: TextureLayerModel,
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

        updateCanvasView(commandBuffer)
    }

    func updateCanvasView(_ commandBuffer: MTLCommandBuffer) {
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

}
