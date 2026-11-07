//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
import FileView
import Metal
import UIKit

extension HandDrawingViewModel {
    func isOpenFile(at index: Int) -> Bool {
        guard let item = fileList.item(index) else { return false }
        return item.fileURL == fileURL(projectName: project.currentProjectName)
    }

    /// Builds the file list from the given project zip URLs (typically every `.zip` under Documents).
    func setupFileList(from fileURLs: [URL]) async {

        // `updateItems` keeps existing list rows and calls `makeItemFromDocuments` only for zips not yet in the list.
        await fileList.updateItems(from: fileURLs) { [weak self] zipFileURL in
            guard let self else { return nil }

            do {
                // Unzip once to read project metadata and the list thumbnail (not the layer textures).
                return try await documentsProjectFileStorage.withUnzippedContents(from: zipFileURL) { [self] workingDirectoryURL in
                    let projectMetaData = try ProjectSnapshot(in: workingDirectoryURL)
                    let thumbnailData = try? Data(
                        contentsOf: workingDirectoryURL.appendingPathComponent(
                            self.thumbnailFileName
                        )
                    )
                    return .init(
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        thumbnail: thumbnailData.flatMap(UIImage.init(data:)),
                        fileURL: zipFileURL
                    )
                }
            } catch {
                Logger.error(error)
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
        let loaded = try await readProject(
            device: device,
            from: zipFileURL
        )

        apply(loaded, projectName: zipFileURL.baseName)

        try await onCanvasUpdate?()

        showToast(.success)
    }

    /// Deletes the saved file at `index` from disk and the file list.
    func deleteFile(index: Int) throws {
        guard let item = fileList.item(index) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        try documentsProjectFileStorage.removeFile(at: item.fileURL)
        fileList.deleteItem(title: item.title)
    }

    /// Restores the canvas from a saved project file.
    func loadFile(
        device: MTLDevice,
        zipFileURL: URL
    ) async throws {
        let loaded = try await readProject(
            device: device,
            from: zipFileURL
        )
        apply(loaded, projectName: zipFileURL.baseName)

        try await onCanvasUpdate?()

        showToast(.success)
    }

    /// Renames a saved file on disk and updates the file list.
    /// - Returns: The title stored in the file list after renaming.
    @discardableResult
    func renameFile(index: Int, newName: String) throws -> String {
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

        let newFileURL = try URL.uniqueFileURL(
            name: normalizedName,
            in: dependencies.fileManager.documentsDirectory,
            fileSuffix: fileList.fileSuffix,
            fileExists: { dependencies.fileManager.fileExists(atPath: $0.path) },
            excludeURL: oldFileURL
        )
        let uniqueName = newFileURL.baseName
        guard uniqueName != oldTitle else {
            return oldTitle
        }

        try documentsProjectFileStorage.renameFile(src: oldFileURL, dst: newFileURL)

        if oldFileURL == fileURL(projectName: project.currentProjectName) {
            project.update(
                projectName: uniqueName,
                updatedAt: Date()
            )
        }
        fileList.renameItem(title: oldTitle, newTitle: uniqueName)

        return uniqueName
    }

    /// Saves the current canvas.
    func saveFile(
        thumbnail: UIImage?,
        zipFileURL: URL
    ) async throws {
        let updatedAt = Date()

        try await writeProject(
            content: .init(
                thumbnail: thumbnail,
                textureLayers: undoableTextureLayers.snapshot,
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

        showToast(.success)
    }

    func upsertFile(thumbnail: UIImage?) {
        let item = currentFileItem(thumbnail: thumbnail)
        if fileList.index(title: item.title) != nil {
            fileList.update(item)
        } else {
            fileList.append(item)
        }
    }
}

private extension HandDrawingViewModel {
    func apply(_ loaded: ProjectContent, projectName: String) {
        if let layers = loaded.textureLayers {
            undoableTextureLayers.setLayers(layers)
        }

        project.update(
            projectName: projectName,
            createdAt: loaded.project.createdAt,
            updatedAt: loaded.project.updatedAt
        )

        if let tool = loaded.drawingTool {
            drawingTool.type = .init(rawValue: tool.type)
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

extension HandDrawingViewModel {
    func updateThumbnails(device: MTLDevice) async {
        let textures = try? await dependencies.localTextureFileRepository.duplicatedTextures(
            undoableTextureLayers.layers.map { $0.id },
            textureSize: undoableTextureLayers.textureSize,
            device: device
        )
        textures?.forEach { texture in
            undoableTextureLayers.updateLayerThumbnail(texture.0, thumbnail: texture.1.makeThumbnail())
        }
    }
}
