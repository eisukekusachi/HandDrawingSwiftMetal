//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import TextureLayerView

@preconcurrency import MetalKit

@objc public final class TextureLayerCanvasView: CanvasView, TextureLayerCanvasUpdating {

    private let liveStorage: TextureLayerCanvasLiveStorage

    /// Layer whose pixels are held in `currentTexture`. May differ from the selected layer until `updateFullCanvas` completes.
    public var currentTextureLayerId: LayerId? {
        liveStorage.currentTextureLayerId
    }

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
        self.liveStorage = .init(
            writeDataToDisk: { layerId, data in
                try await dependencies.localTextureFileRepository.writeDataToDisk(
                    id: layerId,
                    data: data
                )
            },
            updateThumbnail: { id, thumbnail in
                onUpdateLayerThumbnail?(id, thumbnail)
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
        strokeSessionDidCommit
            .sink { [weak self] in
                self?.completeDrawing()
            }
            .store(in: &cancellables)
    }

    override public func initializeCanvas(_ textureSize: CGSize) async throws {
        liveStorage.resetActiveLayer()
        try await super.initializeCanvas(textureSize)

        try viewModel.initializeTextures(textureSize)

        try await updateFullCanvas()
    }

    private func completeDrawing() {
        guard let texture = currentTexture else { return }

        liveStorage.scheduleSaveAfterStroke(
            texture: texture,
            device: renderer.device,
            commandQueue: renderer.commandQueue
        )
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
        liveStorage.setActiveLayer(selectedLayer.id)

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