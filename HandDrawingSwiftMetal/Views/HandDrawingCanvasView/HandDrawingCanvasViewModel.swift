//
//  HandDrawingCanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/02/04.
//

import CanvasView
import Foundation
import MetalKit
import TextureLayerView

@MainActor
final class HandDrawingCanvasViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    private var dependencies: HandDrawingCanvasViewDependencies

    private(set) var textureLayersState: TextureLayersState = TextureLayersState()

    private var textureLayerStorage: CoreDataTextureLayerStorage?

    private let textureLayersStorageController: PersistenceController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )

    private var restoredDataFromCoreData: TextureLayersModel? {
        guard
            let entity = try? textureLayerStorage?.fetch(),
            let model = textureLayerStorage?.textureLayersModel(from: entity)
        else { return nil }
        return model
    }

    init(
        dependencies: HandDrawingCanvasViewDependencies
    ) {
        self.dependencies = dependencies

        self.textureLayerStorage = .init(
            textureLayers: textureLayersState,
            context: textureLayersStorageController.viewContext
        )
    }
}

extension HandDrawingCanvasViewModel {
    func onSetup(
        configuration: CanvasConfiguration,
        device: MTLDevice
    ) async throws -> CanvasConfiguration? {
        let data: TextureLayersModel
        let resolvedConfiguration: CanvasConfiguration

        if let restoredDataFromCoreData {
            do {
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    textureLayers: restoredDataFromCoreData,
                    device: device
                )
                data = restoredDataFromCoreData
                resolvedConfiguration = configuration.newTextureSize(restoredDataFromCoreData.textureSize)

            } catch {
                // Initialize using the configuration values when an error occurs
                let newData = TextureLayersModel(textureSize: configuration.textureSize)
                try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                    textureLayers: newData,
                    device: device
                )
                data = newData
                resolvedConfiguration = configuration

                // Initialize the Core Data storage if fetching fails
                do {
                    try textureLayerStorage?.clearAll()
                } catch {
                    Logger.error("Failed to clear Core Data storage: \(error)")
                }
            }
        } else {
            let newData = TextureLayersModel(textureSize: configuration.textureSize)
            try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                textureLayers: newData,
                device: device
            )
            data = newData
            resolvedConfiguration = configuration
        }

        textureLayersState.update(data)

        return resolvedConfiguration
    }

    func onCompleteDrawing(
        texture: MTLTexture?,
        device: MTLDevice
    ) async throws {
        guard
            let texture,
            let layerId = self.textureLayersState.selectedLayer?.id
        else { return }

        try await saveTexture(
            layerId: layerId,
            texture: texture,
            device: device
        )

        textureLayersState.updateThumbnail(
            layerId,
            texture: texture
        )
    }

    func saveTexture(layerId: UUID, texture: MTLTexture, device: MTLDevice) async throws {
        try await dependencies.textureLayersDocumentsRepository.writeTextureToDisk(
            id: layerId,
            texture: texture,
            device: device
        )
    }

    func onSaveFiles(
        thumbnail: UIImage?,
        device: MTLDevice,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            // Save the thumbnail image into the working directory
            try thumbnail?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent("thumbnail.png")
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the thumbnail")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Copy the texture files into the working directory
            for layer in textureLayersState.layers {
                try await dependencies.textureLayersDocumentsRepository.copyTexture(
                    id: layer.id,
                    to: workingDirectoryURL
                )
            }
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the textures")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Save the texture layers as JSON
            try TextureLayersArchiveModel(
                layers: textureLayersState.layers.map { .init(item: $0) },
                layerIndex: textureLayersState.selectedIndex ?? 0,
                textureSize: textureLayersState.textureSize
            ).write(
                in: workingDirectoryURL
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to save the texture layers")
            )
            Logger.error(error)
            throw error
        }
    }

    func onLoadFiles(
        device: MTLDevice,
        from workingDirectoryURL: URL
    ) async throws {
        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let data: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        try await dependencies.textureLayersDocumentsRepository.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: data,
            device: device
        )

        textureLayersState.update(data)
    }

    func onNewCanvas(
        device: MTLDevice
    ) async throws {
        let textureSize = textureLayersState.textureSize

        let data: TextureLayersModel = .init(
            textureSize: textureSize
        )

        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: data,
            device: device
        )

        textureLayersState.update(data)
    }
}

extension HandDrawingCanvasViewModel {
    func duplicatedTexture(_ id: LayerId, device: MTLDevice) async throws -> MTLTexture? {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            device: device
        )
    }

    func duplicatedTextures(_ ids: [LayerId], device: MTLDevice) async throws -> [(LayerId, MTLTexture)] {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            device: device
        )
    }
}
