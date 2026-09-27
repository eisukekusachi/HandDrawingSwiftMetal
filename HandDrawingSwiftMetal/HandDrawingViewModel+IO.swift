//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import Core
import FileView
import Metal
import TextureLayerView
import UIKit

extension HandDrawingViewModel {
    /// Clears the open canvas in place and overwrites the same zip.
    func clearCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        try await makeBlankCanvas(
            device: device,
            commandQueue: commandQueue
        )
        let updatedAt = Date()

        try await writeProject(
            content: .init(
                thumbnail: nil,
                textureLayers: textureLayersState.model,
                project: .init(project),
                drawingTool: .init(drawingTool),
                brushPalette: .init(brushPalette),
                eraserPalette: .init(eraserPalette)
            ),
            to: zipFileURL(
                projectName: project.currentProjectName
            ),
            projectUpdatedAt: updatedAt
        )

        project.update(updatedAt: updatedAt)
        fileList.setItem(currentFileItem(thumbnail: nil))
        fileList.sortItems()
    }

    /// Deletes a saved file from disk and the file list.
    func deleteCanvas(index: Int) throws {
        guard let item = fileList.item(index) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        try documentsDataStore.removeFile(at: item.fileURL)
        fileList.deleteItem(title: item.title)
    }

    /// Clears the canvas, assigns a new file name, and saves so the file list gains an item.
    func newCanvas(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        let targetURL = try documentsDataStore.uniqueZipFileURL(
            fileName: fileName,
            suffix: fileList.fileSuffix
        )
        let createdAt = Date()
        let updatedAt = Date()

        try await makeBlankCanvas(
            device: device,
            commandQueue: commandQueue
        )

        try await writeProject(
            content: .init(
                thumbnail: nil,
                textureLayers: textureLayersState.model,
                project: .init(project),
                drawingTool: .init(drawingTool),
                brushPalette: .init(brushPalette),
                eraserPalette: .init(eraserPalette)
            ),
            to: targetURL,
            projectCreatedAt: createdAt,
            projectUpdatedAt: updatedAt
        )

        project.update(
            projectName: targetURL.baseName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        fileList.setItem(currentFileItem(thumbnail: nil))
        fileList.sortItems()

        return targetURL
    }

    /// Renames a saved file on disk and updates the file list.
    /// - Returns: The title stored in the file list after renaming.
    @discardableResult
    func renameCanvas(index: Int, newName: String) throws -> String {
        guard let item = fileList.item(index) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        let oldFileURL = item.fileURL
        let oldTitle = item.title
        let normalizedName = URL.normalizedName(
            fallbackName: oldTitle,
            newName: newName
        )

        guard normalizedName != oldTitle else {
            return oldTitle
        }

        let uniqueName = fileList.naming.uniqueTitle(
            from: normalizedName,
            existingTitles: fileList.items.map(\.title)
        )
        guard uniqueName != oldTitle else {
            return oldTitle
        }

        let newFileURL = URL.fileURL(
            in: oldFileURL.deletingLastPathComponent(),
            name: uniqueName,
            fileSuffix: fileList.fileSuffix
        )

        try documentsDataStore.renameFile(at: oldFileURL, to: newFileURL)

        if oldFileURL == zipFileURL(projectName: project.currentProjectName) {
            project.update(
                projectName: uniqueName,
                updatedAt: Date()
            )
        }
        fileList.renameItem(title: oldTitle, newTitle: uniqueName)

        return uniqueName
    }
}

extension HandDrawingViewModel {
    /// Creates blank canvas textures and resets drawing tool / palettes.
    fileprivate func makeBlankCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let newTextureLayersState: TextureLayersModel = .init(textureSize: textureLayersState.textureSize)

        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: newTextureLayersState,
            device: device,
            commandQueue: commandQueue
        )
        textureLayersState.update(newTextureLayersState)

        drawingToolStorage.initializeData()
        brushPalette.initializeData()
        eraserPalette.initializeData()
    }

    func writeProject(
        content: ProjectContent,
        to zipFileURL: URL,
        projectCreatedAt: Date? = nil,
        projectUpdatedAt: Date? = nil
    ) async throws {
        try await documentsDataStore.withZippedContents(to: zipFileURL) { [self] workingDirectoryURL in
            do {
                try content.thumbnail?.pngData()?.write(
                    to: workingDirectoryURL.appendingPathComponent(self.thumbnailFileName)
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
                    try await dependencies.textureLayersDocumentsRepository.copyTexture(
                        id: layer.id,
                        to: workingDirectoryURL
                    )
                }
            } catch {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to create the textures")
                )
            }

            do {
                try TextureLayersArchiveModel(
                    layers: textureLayers.layers,
                    layerIndex: textureLayers.layerIndex,
                    textureSize: textureLayers.textureSize
                ).write(in: workingDirectoryURL)
            } catch {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Failed to save the texture layers")
                )
            }

            try content.drawingTool?.write(in: workingDirectoryURL)
            try content.brushPalette?.write(in: workingDirectoryURL)
            try content.eraserPalette?.write(in: workingDirectoryURL)
            try ProjectArchiveModel(
                createdAt: projectCreatedAt ?? content.project.createdAt,
                updatedAt: projectUpdatedAt ?? content.project.updatedAt
            ).write(in: workingDirectoryURL)
        }
    }

    func readProject(
        device: MTLDevice,
        from zipFileURL: URL
    ) async throws -> ProjectContent {
        try await documentsDataStore.withUnzippedContents(from: zipFileURL) { workingDirectoryURL in
            let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
                in: workingDirectoryURL
            )
            let newTextureLayers: TextureLayersModel = try .init(model: textureLayersArchiveModel)

            let restoredLayers: TextureLayersModel?
            if try await dependencies.textureLayersDocumentsRepository.restoreStorage(
                url: workingDirectoryURL,
                textureLayers: newTextureLayers,
                device: device
            ) {
                restoredLayers = newTextureLayers
            } else {
                restoredLayers = nil
            }

            return ProjectContent(
                thumbnail: nil,
                textureLayers: restoredLayers,
                project: try .init(in: workingDirectoryURL),
                drawingTool: try? .init(in: workingDirectoryURL),
                brushPalette: try? .init(in: workingDirectoryURL),
                eraserPalette: try? .init(in: workingDirectoryURL)
            )
        }
    }
}
