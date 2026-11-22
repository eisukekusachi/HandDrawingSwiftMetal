//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import TextureLayerView

@preconcurrency import MetalKit

@objc public final class TextureLayerCanvasView: CanvasView, TextureLayerCanvasUpdating {

    /// Persists the in-progress drawing on `currentTexture` to Storage.
    private let drawingPersistence: TextureLayerCanvasDrawingPersistence

    private let dependencies: TextureLayerCanvasViewDependencies

    private let onUpdateLayerThumbnail: (@MainActor @Sendable (UUID, UIImage?) -> Void)?

    private lazy var viewModel: TextureLayerCanvasViewModel = {
        .init(
            dependencies: dependencies,
            textureMinimumLength: configuration.textureMinimumLength
        )
    }()

    private var cancellables = Set<AnyCancellable>()

    private let configuration: CanvasConfiguration

    public init(
        dependencies: TextureLayerCanvasViewDependencies,
        device: MTLDevice? = nil,
        configuration: CanvasConfiguration,
        onUpdateLayerThumbnail: (@MainActor @Sendable (UUID, UIImage?) -> Void)? = nil
    ) {
        self.dependencies = dependencies
        self.onUpdateLayerThumbnail = onUpdateLayerThumbnail
        self.configuration = configuration
        self.drawingPersistence = .init(
            saveLayerData: { layerId, data, thumbnail in
                try await dependencies.localTextureFileRepository.writeDataToDisk(
                    id: layerId,
                    data: data
                )
                onUpdateLayerThumbnail?(layerId, thumbnail)
            }
        )
        super.init(
            device: device,
            configuration: configuration,
            renderer: dependencies.renderer
        )
        self.bindData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindData() {
        // When the user ends a stroke, CanvasView merges the realtime stroke into the layer's `currentTexture` on the GPU
        // (not into `canvasTexture`). This fires after that command buffer completes.
        strokeSessionDidCommit
            .sink { [weak self] in
                guard
                    let self,
                    let texture = currentTexture,
                    let layerId = dependencies.textureLayers.selectedLayer?.id
                else { return }

                // Save `currentTexture` to Storage after a short delay.
                drawingPersistence.saveToStorageWithDebouncing(
                    layerId: layerId,
                    texture: texture,
                    device: renderer.device,
                    commandQueue: renderer.commandQueue
                )
            }
            .store(in: &cancellables)
    }

    override public func initializeCanvas(_ textureSize: CGSize) async throws {
        try await super.initializeCanvas(textureSize)

        try viewModel.initializeTextures(textureSize)

        try await updateFullCanvas()
    }

    public func throwIfUnsavedDrawing() throws {
        try drawingPersistence.throwIfUnsavedDrawing()
    }

    public func updateFullCanvas() async throws {
        guard
            let selectedLayer = dependencies.textureLayers.selectedLayer,
            let currentTexture = try await viewModel.duplicatedTexture(
                selectedLayer.id
            ),
            let newCommandBuffer = renderer.newCommandBuffer
        else {
            return
        }

        try await viewModel.updateUnselectedTextures(with: newCommandBuffer)

        try await newCommandBuffer.commitAndWaitAsync()

        try setCurrentTexture(currentTexture)

        updateCanvasDisplay()
    }

    override public func updateCanvasInRealtime() {
        viewModel.updateCanvasTexture(
            realtimeDrawingTexture,
            on: canvasTexture,
            with: currentFrameCommandBuffer
        )
        present()
    }

    override public func updateCanvasDisplay() {
        viewModel.updateCanvasTexture(
            currentTexture,
            on: canvasTexture,
            with: currentFrameCommandBuffer
        )
        present()
    }

    public func saveTextureToLocal(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await viewModel.saveTextureToLocal(
            layerId: layerId,
            textureData: textureData
        )
    }
}