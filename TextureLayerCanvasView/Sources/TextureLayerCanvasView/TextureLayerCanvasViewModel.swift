//
//  TextureLayerCanvasViewModel.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/18.
//

import CanvasView
import Combine
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class TextureLayerCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let textureLayersState: TextureLayersState

    let dependencies: TextureLayerCanvasViewDependencies

    /// Texture that combines the textures of all layers below the selected layer
    private var unselectedBottomTexture: MTLTexture?

    /// Texture that combines the textures of all layers above the selected layer
    private var unselectedTopTexture: MTLTexture?

    private var cancellables = Set<AnyCancellable>()

    private var renderer: MTLRendering

    private lazy var canvasRenderer: TextureLayerCanvasRenderer = {
        .init(renderer: renderer)
    }()

    init(
        textureLayersState: TextureLayersState,
        renderer: MTLRendering,
        dependencies: TextureLayerCanvasViewDependencies? = nil
    ) {
        self.textureLayersState = textureLayersState
        self.dependencies = dependencies ?? .init()
        self.renderer = renderer
    }

    func initializeTextures(_ textureSize: CGSize) throws {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
                Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        guard
            let unselectedBottomTexture = renderer.makeTexture(textureSize),
            let unselectedTopTexture = renderer.makeTexture(textureSize)
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Failed to create new texture"
                )
            )
            Logger.error(error)
            throw error
        }
        self.unselectedBottomTexture = unselectedBottomTexture
        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.unselectedTopTexture = unselectedTopTexture
        self.unselectedTopTexture?.label = "unselectedTopTexture"
    }

    func unpdateUnselectedTextures(
        textureLayers: TextureLayers?,
        with commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let textureLayers else { return }

        let selection: TextureLayerSelection = .init(
            textureLayers: textureLayers
        )

        try await canvasRenderer.renderLayersIntoTextures(
            layers: selection.topLayers,
            textureRepository: dependencies.textureLayersDocumentsRepository,
            on: unselectedTopTexture,
            commandBuffer: commandBuffer
        )

        try await canvasRenderer.renderLayersIntoTextures(
            layers: selection.bottomLayers,
            textureRepository: dependencies.textureLayersDocumentsRepository,
            on: unselectedBottomTexture,
            commandBuffer: commandBuffer
        )
    }

    func updateCanvasTexture(
        _ texture: MTLTexture?,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let destinationTexture,
            let commandBuffer,
            let selectedLayer = textureLayersState.selectedLayer
        else { return }

        canvasRenderer.renderCanvas(
            unselectedTopTexture: unselectedTopTexture,
            currentTextureLayer: .init(
                isVisible: selectedLayer.isVisible,
                alpha: selectedLayer.alpha,
                texture: texture
            ),
            unselectedBottomTexture: unselectedBottomTexture,
            canvasTexture: destinationTexture,
            commandBuffer: commandBuffer
        )
    }
}

extension TextureLayerCanvasViewModel {

    func duplicateTextureFromDocumentsDirectory(
        _ id: LayerId
    ) async throws -> MTLTexture? {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [LayerId]
    ) async throws -> [(LayerId, MTLTexture)] {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: renderer.device
        )
    }

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await dependencies.textureLayersDocumentsRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }
}
