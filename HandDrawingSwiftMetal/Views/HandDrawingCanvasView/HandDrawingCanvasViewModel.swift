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

    var textureSize: CGSize? {
        textureLayersState?.textureSize
    }

    private var dependencies: HandDrawingCanvasViewDependencies

    private(set) var textureLayersState: TextureLayersState?

    init(
        device: MTLDevice,
        dependencies: HandDrawingCanvasViewDependencies
    ) {
        self.dependencies = dependencies

        self.textureLayersState = TextureLayersState(
            device: device
        )
    }
}

extension HandDrawingCanvasViewModel {
    func onSetup(
        restoredData: TextureLayersModel?,
        configuration: CanvasConfiguration,
        device: MTLDevice
    ) async throws -> CanvasConfiguration? {
        let data: TextureLayersModel
        let resolvedConfiguration: CanvasConfiguration

        if let restoredData {
            do {
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    textureLayers: restoredData,
                    device: device
                )

                data = restoredData
                resolvedConfiguration = configuration.newTextureSize(restoredData.textureSize)

            } catch {
                // Initialize the storage on error
                let newData = TextureLayersModel(textureSize: configuration.textureSize)
                try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                    textureLayers: newData,
                    device: device
                )
                data = newData
                resolvedConfiguration = configuration
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

        textureLayersState?.update(data)

        return resolvedConfiguration
    }

    func onCompleteDrawing(
        texture: MTLTexture?,
        device: MTLDevice
    ) async throws {
        guard
            let texture,
            let layerId = self.textureLayersState?.selectedLayer?.id
        else { return }

        try await dependencies.textureLayersDocumentsRepository.writeTextureToDisk(
            texture: texture,
            for: layerId,
            device: device
        )

        textureLayersState?.updateThumbnail(
            layerId,
            texture: texture
        )
    }

    func onSaveFiles(
        thumbnail: UIImage?,
        device: MTLDevice,
        to workingDirectoryURL: URL
    ) async throws {
        guard
            let textureLayersState
        else { return }

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
            // Copy all textures from the textureRepository
            let textures = try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
                textureLayersState.layers.map { $0.id },
                device: device
            )

            try await withThrowingTaskGroup(of: Void.self) { group in
                for texture in textures {
                    group.addTask {
                        try await texture.write(
                            in: workingDirectoryURL,
                            device: device
                        )
                    }
                }
                try await group.waitForAll()
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
        guard let textureLayersState else { return }

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
        guard let textureLayersState else { return }

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
    func duplicatedTexture(_ id: LayerId, device: MTLDevice) async throws -> IdentifiedTexture? {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            device: device
        )
    }

    func duplicatedTextures(_ ids: [LayerId], device: MTLDevice) async throws -> [IdentifiedTexture]? {
        try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            device: device
        )
    }
}
