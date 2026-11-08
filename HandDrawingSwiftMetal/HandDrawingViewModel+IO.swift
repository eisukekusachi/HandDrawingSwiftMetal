//
//  Created by Eisuke Kusachi
//

import Core
import FileView
import Metal
import TextureLayerView
import UIKit

extension HandDrawingViewModel {
    /// Creates a new project file with a blank canvas and adds it to the file list.
    func newProject(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        let targetURL = try URL.uniqueFileURL(
            name: fileName,
            in: dependencies.fileManager.documentsDirectory,
            fileSuffix: fileList.fileSuffix,
            fileExists: { dependencies.fileManager.fileExists(atPath: $0.path) }
        )
        let createdAt = Date()
        let updatedAt = Date()

        try await saveBlankProject(
            to: targetURL,
            device: device,
            commandQueue: commandQueue,
            projectCreatedAt: createdAt,
            projectUpdatedAt: updatedAt
        )

        project.update(
            projectName: targetURL.baseName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        fileList.append(currentFileItem(thumbnail: nil))
        fileList.sortItems()

        return targetURL
    }

    func writeProject(
        content: ProjectContent,
        to zipFileURL: URL,
        projectCreatedAt: Date? = nil,
        projectUpdatedAt: Date? = nil
    ) async throws {
        try await documentsProjectFileStorage.withZippedContents(to: zipFileURL) { [self] temporaryDirectoryURL in
            do {
                try content.thumbnail?.pngData()?.write(
                    to: temporaryDirectoryURL.appendingPathComponent(self.thumbnailFileName)
                )
            } catch {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to create the thumbnail")
                )
            }

            guard let textureLayers = content.textureLayers else {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to save the texture layers")
                )
            }

            do {
                for layer in textureLayers.layers {
                    try await dependencies.localTextureFileRepository.copyTexture(
                        id: layer.id,
                        to: temporaryDirectoryURL
                    )
                }
            } catch {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to create the textures")
                )
            }

            do {
                try textureLayers.write(in: temporaryDirectoryURL)
            } catch {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to save the texture layers")
                )
            }

            try content.drawingTool?.write(in: temporaryDirectoryURL)
            try content.brushPalette?.write(in: temporaryDirectoryURL)
            try content.eraserPalette?.write(in: temporaryDirectoryURL)
            try ProjectSnapshot(
                createdAt: projectCreatedAt ?? content.project.createdAt,
                updatedAt: projectUpdatedAt ?? content.project.updatedAt
            ).write(in: temporaryDirectoryURL)
        }
    }

    func readProject(
        from zipFileURL: URL
    ) async throws -> ProjectContent {
        try await documentsProjectFileStorage.withUnzippedContents(from: zipFileURL) { [self] temporaryDirectoryURL in
            let newTextureLayers = try TextureLayersSnapshot(in: temporaryDirectoryURL)
            if newTextureLayers.layers.isEmpty || newTextureLayers.textureSize == .zero {
                let error = NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Unable to find texture layer files")
                )
                Logger.error(error)
                throw error
            }

            try await dependencies.localTextureFileRepository.restoreStorage(
                from: temporaryDirectoryURL,
                ids: newTextureLayers.layers.map(\.id),
                textureSize: newTextureLayers.textureSize
            )

            return ProjectContent(
                thumbnail: nil,
                textureLayers: newTextureLayers,
                project: try .init(in: temporaryDirectoryURL),
                drawingTool: try? .init(in: temporaryDirectoryURL),
                brushPalette: try? .init(in: temporaryDirectoryURL),
                eraserPalette: try? .init(in: temporaryDirectoryURL)
            )
        }
    }
}

private extension HandDrawingViewModel {

    func saveBlankProject(
        to zipFileURL: URL,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        projectCreatedAt: Date?,
        projectUpdatedAt: Date
    ) async throws {
        try await makeBlankCanvas(
            device: device,
            commandQueue: commandQueue
        )
        try await writeProject(
            content: .init(
                thumbnail: nil,
                textureLayers: undoableTextureLayers.snapshot,
                project: .init(project),
                drawingTool: .init(drawingTool),
                brushPalette: .init(brushPalette),
                eraserPalette: .init(eraserPalette)
            ),
            to: zipFileURL,
            projectCreatedAt: projectCreatedAt,
            projectUpdatedAt: projectUpdatedAt
        )
    }
}
