//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit

/// A class that combines `TextureRepository` textures and renders them on the canvas using `MTLRenderer`
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
            textureSize >= MTLRenderer.minimumTextureSize,
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

        let bottomPublisher = mergeLayerTextures(
            layers: bottomLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            textureRepository: textureRepository,
            into: unselectedBottomTexture,
            with: commandBuffer
        )

        let topPublisher = mergeLayerTextures(
            layers: topLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
            textureRepository: textureRepository,
            into: unselectedTopTexture,
            with: commandBuffer
        )

        let selectedPublisher = mergeLayerTextures(
            layers: [opaqueLayer],
            textureRepository: textureRepository,
            into: selectedTexture,
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

    /// Updates the canvas
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

}

extension CanvasRenderer {

    /// Renders `texture` onto a texture retrieved from the repository using an internally created command buffer, and returns the rendered texture
    func renderTextureFromRepository(
        texture: MTLTexture,
        for textureRepositoryId: UUID
    ) -> AnyPublisher<MTLTexture, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.repositoryUnavailable).eraseToAnyPublisher()
        }

        guard let temporaryCommandBuffer = self.device.makeCommandQueue()?.makeCommandBuffer() else {
            Logger.standard.error("Failed to create command buffer")
            return Fail(error: TextureRepositoryError.failedToUnwrap).eraseToAnyPublisher()
        }

        return renderTextureFromRepository(
            texture: texture,
            for: textureRepositoryId,
            in: textureRepository,
            with: temporaryCommandBuffer
        )
        .flatMap { targetTexture -> AnyPublisher<MTLTexture, Error> in
            Future { promise in
                temporaryCommandBuffer.addCompletedHandler { completedBuffer in
                    if completedBuffer.status == .completed {
                        promise(.success(targetTexture))
                    } else {
                        let error = completedBuffer.error ?? TextureRepositoryError.failedToCommitCommandBuffer
                        Logger.standard.error("Command buffer failed with error: \(error.localizedDescription)")
                        promise(.failure(error))
                    }
                }
                temporaryCommandBuffer.commit()
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    /// Renders `texture` onto a texture retrieved from `textureRepository`, and returns the rendered texture
    func renderTextureFromRepository(
        texture: MTLTexture,
        for destinationTextureId: UUID,
        in textureRepository: TextureRepository?,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<MTLTexture, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.repositoryUnavailable).eraseToAnyPublisher()
        }

        return textureRepository.getTexture(
            uuid: destinationTextureId,
            textureSize: texture.size
        )
        .tryMap { [weak self] result -> MTLTexture in
            guard
                let `self`,
                let targetTexture = result.texture,
                let flippedTextureBuffers = self.flippedTextureBuffers
            else {
                throw TextureRepositoryError.failedToUnwrap
            }

            self.renderer.drawTexture(
                texture: texture,
                buffers: flippedTextureBuffers,
                withBackgroundColor: .clear,
                on: targetTexture,
                with: commandBuffer
            )

            return targetTexture
        }
        .eraseToAnyPublisher()
    }

    func mergeLayerTextures(
        layers: [TextureLayerModel],
        textureRepository: TextureRepository?,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        guard let textureRepository else {
            Logger.standard.warning("The texture repository is unavailable")
            return Fail(error: TextureRepositoryError.repositoryUnavailable).eraseToAnyPublisher()
        }

        // Clear the destination texture before merging
        renderer.clearTexture(texture: destinationTexture, with: commandBuffer)

        // If no layers, return immediately as success
        guard !layers.isEmpty else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        // Fetch textures from the repository
        return textureRepository.getTextures(
            uuids: layers.map { $0.id },
            textureSize: destinationTexture.size
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
