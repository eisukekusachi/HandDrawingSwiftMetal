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
    }

    override public func initializeCanvas(_ textureSize: CGSize) async throws {
        try await super.initializeCanvas(textureSize)

        try viewModel.initializeTextures(textureSize)

        try await updateFullCanvasTexture()
    }

    private func completeDrawing() {
        guard
            let texture = currentTexture,
            let layerId = textureLayersState.selectedLayer?.id
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
            let currentTexture = try await viewModel.duplicateTextureFromDocumentsDirectory(
                selectedLayer.id
            ),
            let newCommandBuffer = renderer.newCommandBuffer
        else {
            return
        }

        try await viewModel.unpdateUnselectedTextures(
            textureLayers: .init(state: textureLayersState),
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()

        try setCurrentTexture(currentTexture)

        updateCanvasTextureUsingCurrentTexture()
    }

    override public func updateCanvasTextureUsingRealtimeDrawingTexture() {
        viewModel.updateCanvasTexture(
            realtimeDrawingTexture,
            on: canvasTexture,
            with: currentFrameCommandBuffer
        )
        present()
    }

    override public func updateCanvasTextureUsingCurrentTexture() {
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
