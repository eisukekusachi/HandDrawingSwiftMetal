//
//  TextureLayerCanvasView.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/18.
//

import CanvasView
import Combine
import TextureLayerView

@preconcurrency import MetalKit

@objc public final class TextureLayerCanvasView: CanvasView {

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let textureLayersState: TextureLayersState

    private lazy var textureLayerRenderer: TextureLayerRenderer = {
        .init(renderer: renderer)
    }()

    private lazy var viewModel: TextureLayerCanvasViewModel = {
        .init(
            textureLayersState: textureLayersState,
            renderer: renderer
        )
    }()

    private var cancellables = Set<AnyCancellable>()

    private let configuration: CanvasConfiguration

    public init(
        textureLayersState: TextureLayersState,
        device: MTLDevice? = nil,
        configuration: CanvasConfiguration
    ) {
        self.textureLayersState = textureLayersState
        self.configuration = configuration
        super.init(
            device: device,
            configuration: configuration
        )
        self.bindData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindData() {
        strokeEvents
            .sink { [weak self] event in
                if case .strokeCompleted = event {
                    self?.completeDrawing()
                }
            }
            .store(in: &cancellables)

        viewModel.updateCanvasTextureSubject
            .sink { [weak self] texture in
                guard let `self` else { return }
                if let texture {
                    try? self.setCurrentTexture(texture)
                }
                self.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        viewModel.updateFullCanvasTextureSubject
            .sink {
                Task { [weak self] in
                    guard let `self` else { return }
                    try? await self.updateFullCanvasTexture()
                }
            }
            .store(in: &cancellables)
    }

    private func completeDrawing() {
        guard
            let texture = self.currentTexture,
            let layerId = self.textureLayersState.selectedLayer?.id
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

                await self.viewModel.textureLayersState.updateThumbnail(
                    layerId,
                    texture: texture
                )
            } catch {
                Logger.error(error)
            }
        }
    }

    public func updateFullCanvasTexture() async throws {
        guard
            let selectedLayer = textureLayersState.selectedLayer,
            let textureLayers: TextureLayersRenderContext = .init(state: textureLayersState),
            let currentTexture = await viewModel.duplicateTextureFromDocumentsDirectory(
                selectedLayer.id
            )
        else {
            return
        }

        let textures = await viewModel.duplicateTexturesFromDocumentsDirectory(
            textureLayers.layers.map { $0.id }
        )

        try await textureLayerRenderer.refreshUnselectedTextures(
            textureLayers: textureLayers,
            textures: textures
        )
        try setCurrentTexture(currentTexture)

        updateCanvasTextureUsingCurrentTexture()
    }

    override public func initializeCanvas(_ textureSize: CGSize) async throws {
        try await super.initializeCanvas(textureSize)

        try textureLayerRenderer.initializeTextures(textureSize: textureSize)

        try await updateFullCanvasTexture()
    }

    override public func updateCanvasTextureUsingRealtimeDrawingTexture() {
        updateCanvasTexture(realtimeDrawingTexture)
        present()
    }

    override public func updateCanvasTextureUsingCurrentTexture() {
        updateCanvasTexture(currentTexture)
        present()
    }

    private func updateCanvasTexture(_ texture: MTLTexture?) {
        guard let selectedLayer = textureLayersState.selectedLayer else { return }

        textureLayerRenderer.updateCanvasTexture(
            textureLayer: .init(
                isVisible: selectedLayer.isVisible,
                alpha: selectedLayer.alpha,
                texture: texture ?? currentTexture
            ),
            canvasTexture: canvasTexture,
            commandBuffer: currentFrameCommandBuffer
        )
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
