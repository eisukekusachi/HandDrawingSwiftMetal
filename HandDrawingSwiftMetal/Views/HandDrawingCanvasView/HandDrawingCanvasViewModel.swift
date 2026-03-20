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

    private var dependencies: HandDrawingCanvasViewDependencies?

    init(
        dependencies: HandDrawingCanvasViewDependencies? = nil
    ) {
        self.dependencies = dependencies ?? HandDrawingCanvasViewDependencies()
    }

    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws {
        guard let dependencies else { return }
        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: textureLayers,
            device: device
        )
    }

    func restoreStorage(
        url sourceFolderURL: URL,
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) async throws {
        guard let dependencies else { return }
        try await dependencies.textureLayersDocumentsRepository.restoreStorage(
            url: sourceFolderURL,
            textureLayers: textureLayers,
            device: device
        )
    }

    func restoreStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws {
        guard let dependencies else { return }
        try dependencies.textureLayersDocumentsRepository.restoreStorage(
            textureLayers: textureLayers,
            device: device
        )
    }
}

extension HandDrawingCanvasViewModel {
    func duplicatedTexture(_ id: LayerId, device: MTLDevice) async throws -> IdentifiedTexture? {
        guard let dependencies else { return nil }
        return try await dependencies.textureLayersDocumentsRepository.duplicatedTexture(
            id,
            device: device
        )
    }

    func duplicatedTextures(_ ids: [LayerId], device: MTLDevice) async throws -> [IdentifiedTexture]? {
        guard let dependencies else { return nil }
        return try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            ids,
            device: device
        )
    }

    func writeTexture(
        texture: MTLTexture,
        for id: LayerId,
        device: MTLDevice
    ) async throws {
        guard let dependencies else { return }
        try await dependencies.textureLayersDocumentsRepository.writeTextureToDisk(
            texture: texture,
            for: id,
            device: device
        )
    }

    func exportFiles(
        canvasTexture: MTLTexture?,
        thumbnailLength: CGFloat = 500,
        textureLayers: TextureLayersState?,
        device: MTLDevice,
        to workingDirectoryURL: URL
    ) async throws {
        guard
            let dependencies,
            let textureLayers
        else { return }

        do {
            // Save the thumbnail image into the working directory
            try thumbnail(canvasTexture: canvasTexture, length: thumbnailLength)?.pngData()?.write(
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
                textureLayers.layers.map { $0.id },
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
                layers: textureLayers.layers.map { .init(item: $0) },
                layerIndex: textureLayers.selectedIndex ?? 0,
                textureSize: textureLayers.textureSize
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

    func thumbnail(canvasTexture: MTLTexture?, length: CGFloat = 500) -> UIImage? {
        canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }
}
