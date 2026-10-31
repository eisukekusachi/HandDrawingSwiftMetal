//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import TextureLayerView

@preconcurrency import MetalKit

@objc public final class TextureLayerCanvasView: CanvasView, TextureLayerCanvasUpdating {

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let dependencies: TextureLayerCanvasViewDependencies

    private let onUpdateLayerThumbnail: (@MainActor @Sendable (UUID, UIImage?) -> Void)?

    private lazy var viewModel: TextureLayerCanvasViewModel = {
        .init(dependencies: dependencies)
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
        try await super.initializeCanvas(textureSize)

        try viewModel.initializeTextures(textureSize)

        try await updateFullCanvas()
    }

    private func completeDrawing() {
        guard
            let texture = currentTexture,
            let layerId = dependencies.textureLayers.selectedLayer?.id
        else { return }

        let device = renderer.device
        let commandQueue = renderer.commandQueue

        drawingDebouncer.perform { [weak self] in
            guard let `self` else { return }
            do {
                let textureData = try await texture.data(
                    device: device,
                    commandQueue: commandQueue
                )
                try await self.viewModel.saveTextureToDocumentsDirectory(
                    layerId: layerId,
                    textureData: textureData
                )
                let thumbnail = texture.makeThumbnail()
                await MainActor.run {
                    self.onUpdateLayerThumbnail?(layerId, thumbnail)
                }
            } catch {
                Logger.error(error)
            }
        }
    }

    public func updateFullCanvas() async throws {
        guard
            let selectedLayer = dependencies.textureLayers.selectedLayer,
            let currentTexture = try await viewModel.duplicateTextureFromDocumentsDirectory(
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

    public func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await viewModel.saveTextureToDocumentsDirectory(
            layerId: layerId,
            textureData: textureData
        )
    }
}
