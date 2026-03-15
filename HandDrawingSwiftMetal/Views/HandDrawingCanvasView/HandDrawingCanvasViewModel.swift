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

    func exportFiles(
        canvasTexture: MTLTexture?,
        thumbnailLength: CGFloat = 500,
        textureLayers: TextureLayersState?,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?,
        device: MTLDevice,
        to workingDirectoryURL: URL
    ) async throws {
        guard
            let textureLayers,
            let textureLayersDocumentsRepository
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
            let textures = try await textureLayersDocumentsRepository.duplicatedTextures(
                textureLayers.layers.map { $0.id }
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
