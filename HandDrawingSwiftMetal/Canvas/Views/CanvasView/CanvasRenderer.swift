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

    private var textureRepository: (any TextureRepository)!

    private let renderer: (any MTLRendering)!

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(
        textureRepository: TextureRepository = SingletonTextureInMemoryRepository.shared,
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.textureRepository = textureRepository
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

    func getBottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    func getTopLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    func setCanvas(_ canvasView: CanvasViewProtocol?) {
        self.canvasView = canvasView
    }

    func resetCommandBuffer() {
        canvasView?.resetCommandBuffer()
    }

    /// Updates the canvas after updating all textures.
    /// This helps maintain high drawing performance even as the number of layers increases.
    func updateCanvasAfterUpdatingAllTextures(
        canvasState: CanvasState,
        commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let commandBuffer,
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else { return }

        Publishers.Zip(
            Publishers.Zip(
                renderTexturesFromRepositoryToTexturePublisher(
                    layers: getBottomLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
                    into: unselectedBottomTexture,
                    with: commandBuffer
                ),
                renderTexturesFromRepositoryToTexturePublisher(
                    layers: getTopLayers(selectedIndex: selectedIndex, layers: canvasState.layers),
                    into: unselectedTopTexture,
                    with: commandBuffer
                )
            ),
            renderTextureFromRepositoryToTexturePublisher(
                layer: selectedLayer,
                into: selectedTexture,
                with: commandBuffer
            )
        )
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished: break
            case .failure: break
            }
        }, receiveValue: { [weak self] _ in
            self?.updateCanvas(
                selectedLayer: selectedLayer,
                with: commandBuffer
            )
        })
        .store(in: &cancellables)
    }

    /// Updates the canvas using `unselectedTopTexture` and `unselectedBottomTexture`
    func updateCanvas(
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

        refreshCanvasView(commandBuffer)
    }

    func renderTextureToLayerInRepository(
        texture: MTLTexture,
        targetTextureId: UUID,
        callback: ((MTLTexture) -> Void)? = nil
    ) {
        textureRepository?.loadTexture(targetTextureId)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished: break
                case .failure: break
                }
            }, receiveValue: { [weak self] targetTexture in
                guard
                    let flippedTextureBuffers = self?.flippedTextureBuffers,
                    let targetTexture,
                    let temporaryRenderCommandBuffer = self?.device.makeCommandQueue()?.makeCommandBuffer()
                else { return }

                temporaryRenderCommandBuffer.label = "commandBuffer"

                self?.renderer.drawTexture(
                    texture: texture,
                    buffers: flippedTextureBuffers,
                    withBackgroundColor: .clear,
                    on: targetTexture,
                    with: temporaryRenderCommandBuffer
                )
                temporaryRenderCommandBuffer.commit()

                callback?(texture)
            })
            .store(in: &cancellables)
    }

    func renderTextureFromRepositoryToTexturePublisher(
        layer: TextureLayerModel,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        // Clear `destinationTexture` here
        renderer.clearTexture(texture: destinationTexture, with: commandBuffer)

        return textureRepository.loadTexture(layer.id)
            .compactMap { $0 }
            .handleEvents(receiveOutput: { [weak self] texture in
                guard let flippedTextureBuffers = self?.flippedTextureBuffers else { return }

                self?.renderer.drawTexture(
                    texture: texture,
                    buffers: flippedTextureBuffers,
                    withBackgroundColor: .clear,
                    on: destinationTexture,
                    with: commandBuffer
                )
            })
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func renderTexturesFromRepositoryToTexturePublisher(
        layers: [TextureLayerModel],
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) -> AnyPublisher<Void, Error> {
        // Clear `destinationTexture` here
        renderer.clearTexture(texture: destinationTexture, with: commandBuffer)

        // Emit `Void` as a success value when the array is empty
        guard
            !layers.isEmpty
        else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return textureRepository.loadTextures(
            layers.map { $0.id }
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

    func refreshCanvasView(_ commandBuffer: MTLCommandBuffer) {
        guard let renderTexture = canvasView?.renderTexture else { return }

        MTLRenderer.shared.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            on: renderTexture,
            device: device,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

}
