//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class TextureLayerCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        dependencies.textureLayers.textureSize
    }

    let dependencies: TextureLayerCanvasViewDependencies

    /// Texture that combines the textures of all layers below the selected layer
    private var unselectedBottomTexture: MTLTexture?

    /// Texture that combines the textures of all layers above the selected layer
    private var unselectedTopTexture: MTLTexture?

    private var cancellables = Set<AnyCancellable>()

    private lazy var canvasRenderer: TextureLayerCanvasRenderer = {
        .init(renderer: dependencies.renderer)
    }()

    init(
        dependencies: TextureLayerCanvasViewDependencies
    ) {
        self.dependencies = dependencies
    }

    func initializeTextures(_ textureSize: CGSize) throws {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
                Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    format: String(localized: "Texture size is below the minimum: %lf %lf"),
                    textureSize.width,
                    textureSize.height
                )
            )
            Logger.error(error)
            throw error
        }

        guard
            let unselectedBottomTexture = dependencies.renderer.makeTexture(textureSize),
            let unselectedTopTexture = dependencies.renderer.makeTexture(textureSize)
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

    func updateUnselectedTextures(
        with commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let unselectedLayers = UnselectedTextureLayers(source: dependencies.textureLayers) else {
            return
        }

        try await canvasRenderer.renderLayersIntoTextures(
            layers: unselectedLayers.topLayers,
            textureRepository: dependencies.documentsTextureDataRepository,
            on: unselectedTopTexture,
            commandBuffer: commandBuffer
        )

        try await canvasRenderer.renderLayersIntoTextures(
            layers: unselectedLayers.bottomLayers,
            textureRepository: dependencies.documentsTextureDataRepository,
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
            let selectedLayer = dependencies.textureLayers.selectedLayer
        else { return }

        canvasRenderer.renderCanvas(
            unselectedTopTexture: unselectedTopTexture,
            selectedTextureLayer: .init(
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
        _ id: UUID
    ) async throws -> MTLTexture? {
        try await dependencies.documentsTextureDataRepository.duplicatedTexture(
            id,
            textureSize: textureSize,
            device: dependencies.renderer.device
        )
    }

    func duplicateTexturesFromDocumentsDirectory(
        _ ids: [UUID]
    ) async throws -> [(UUID, MTLTexture)] {
        try await dependencies.documentsTextureDataRepository.duplicatedTextures(
            ids,
            textureSize: textureSize,
            device: dependencies.renderer.device
        )
    }

    func saveTextureToDocumentsDirectory(
        layerId: UUID,
        textureData: Data
    ) async throws {
        try await dependencies.documentsTextureDataRepository.writeDataToDisk(
            id: layerId,
            data: textureData
        )
    }
}
