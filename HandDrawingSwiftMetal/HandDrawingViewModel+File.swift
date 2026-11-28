//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import FileView
import Metal
import UIKit

extension HandDrawingViewModel {

    /// Scans the injected Documents directory and builds the file list.
    func setupFileListFromDocumentsDirectory() async {
        let fileURLs: [URL]
        do {
            fileURLs = try dependencies.fileManager.contentsOfDirectory(
                at: dependencies.fileManager.documentsDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            Core.Logger.error(error)
            fileURLs = []
        }

        await fileList.updateItems(from: fileURLs) { [weak self] zipFileURL in
            guard let self else { return nil }
            do {
                return try await dependencies.documentsProjectFileStorage.withUnzippedContents(from: zipFileURL) { [self] workingDirectoryURL in
                    let projectMetaData = try ProjectSnapshot(in: workingDirectoryURL)
                    let thumbnailData = try? Data(
                        contentsOf: workingDirectoryURL.appendingPathComponent(self.thumbnailFileName)
                    )

                    return FileItem(
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        thumbnail: thumbnailData.flatMap(UIImage.init(data:)),
                        fileURL: zipFileURL
                    )
                }
            } catch {
                Core.Logger.error(error)
                return nil
            }
        }
    }

    /// Creates a new canvas file and loads it into the view model.
    func createFile(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let zipFileURL = try await newProject(
            fileName: fileName,
            device: device,
            commandQueue: commandQueue
        )
        let loaded = try await readProject(from: zipFileURL)

        try apply(loaded, projectName: zipFileURL.baseName)

        try await onCanvasUpdate?()
    }

    /// Deletes the saved file at `index` from disk and the file list.
    func deleteFile(index: Int) throws {
        guard let item = fileList.item(index) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        try dependencies.documentsProjectFileStorage.removeFile(at: item.fileURL)
        fileList.deleteItem(title: item.title)
    }

    /// Restores the canvas from a saved project file.
    func loadFile(
        zipFileURL: URL
    ) async throws {
        let loaded = try await readProject(from: zipFileURL)
        try apply(loaded, projectName: zipFileURL.baseName)

        try await onCanvasUpdate?()
    }

    /// Renames a saved file on disk and updates the file list.
    func renameFile(index: Int, newName: String) throws {
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
            return
        }

        let newFileURL = try URL.uniqueFileURL(
            name: normalizedName,
            in: dependencies.fileManager.documentsDirectory,
            fileSuffix: fileList.fileSuffix,
            fileExists: { dependencies.fileManager.fileExists(atPath: $0.path) },
            excludeURL: oldFileURL
        )
        let uniqueName = newFileURL.baseName
        guard uniqueName != oldTitle else {
            return
        }

        try dependencies.documentsProjectFileStorage.renameFile(src: oldFileURL, dst: newFileURL)

        if oldFileURL == fileURL(projectName: project.currentProjectName) {
            project.update(
                projectName: uniqueName,
                updatedAt: Date()
            )
        }
        fileList.renameItem(title: oldTitle, newTitle: uniqueName)
    }

    /// Saves the current canvas.
    func saveFile(
        thumbnail: UIImage?,
        zipFileURL: URL
    ) async throws {
        let textureLayersSnapshot = undoableTextureLayers.snapshot
        guard !textureLayersSnapshot.layers.isEmpty else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to save the texture layers")
            )
        }
        let updatedAt = Date()

        try await writeProject(
            content: .init(
                thumbnail: thumbnail,
                textureLayers: textureLayersSnapshot,
                project: .init(project),
                drawingTool: .init(drawingTool),
                brushPalette: .init(brushPalette),
                eraserPalette: .init(eraserPalette)
            ),
            to: zipFileURL,
            projectUpdatedAt: updatedAt
        )

        project.update(updatedAt: updatedAt)
        upsertFile(thumbnail: thumbnail)
        fileList.sortItems()
    }

    func upsertFile(thumbnail: UIImage?) {
        let item = currentFileItem(thumbnail: thumbnail)
        if fileList.index(title: item.title) != nil {
            fileList.update(item)
        } else {
            fileList.append(item)
        }
    }

    /// Updates layer-list thumbnails from the textures stored on disk.
    func updateThumbnails(device: MTLDevice) async {
        let textures = try? await dependencies.localTextureFileRepository.duplicatedTextures(
            undoableTextureLayers.layers.map(\.id),
            textureSize: undoableTextureLayers.textureSize,
            device: device
        )
        textures?.forEach { id, texture in
            undoableTextureLayers.updateLayerThumbnail(id, thumbnail: texture.makeThumbnail())
        }
    }
}

private extension HandDrawingViewModel {
    func apply(_ loaded: ProjectContent, projectName: String) throws {
        if let layers = loaded.textureLayers {
            try undoableTextureLayers.setLayers(layers)
        }

        project.update(
            projectName: projectName,
            createdAt: loaded.project.createdAt,
            updatedAt: loaded.project.updatedAt
        )

        if let tool = loaded.drawingTool {
            drawingTool.type = tool.drawingToolType
            drawingTool.brushDiameter = tool.brushDiameter
            drawingTool.eraserDiameter = tool.eraserDiameter
        }
        if let brush = loaded.brushPalette {
            brushPalette.update(
                colors: brush.hexColors.map { UIColor(hex: $0) },
                selectedIndex: brush.index
            )
        }
        if let eraser = loaded.eraserPalette {
            eraserPalette.update(
                alphas: eraser.alphas,
                selectedIndex: eraser.index
            )
        }
    }
}