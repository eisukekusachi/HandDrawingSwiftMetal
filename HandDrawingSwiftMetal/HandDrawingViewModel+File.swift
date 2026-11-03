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
        return item.fileURL == zipFileURL(projectName: project.currentProjectName)
    }

    /// Builds the file list from the given project zip URLs (typically every `.zip` under Documents).
    func setupFileList(from fileURLs: [URL]) async throws {

        // `updateItems` keeps existing list rows and calls `makeItemFromDocuments` only for zips not yet in the list.
        try await fileList.updateItems(from: fileURLs) { [weak self] zipFileURL in
            guard let self else { return nil }

            // Unzip once to read project metadata and the list thumbnail (not the layer textures).
            return try await documentsDataStore.withUnzippedContents(from: zipFileURL) { [self] workingDirectoryURL in
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
        }
    }

    /// Clears the open canvas and bumps the project updatedAt.
    func clearCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        try await makeBlankCanvas(
            device: device,
            commandQueue: commandQueue
        )

        project.update(updatedAt: Date())
        fileList.update(currentFileItem(thumbnail: nil))
        fileList.sortItems()

        try await onCanvasUpdate?()
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

    /// Renames a file in the list and returns the stored title.
    func renameFile(index: Int, newName: String) throws -> String {
        try renameCanvas(index: index, newName: newName)
    }

    /// Deletes the saved file at `index` from disk and the file list.
    func deleteFile(
        index: Int,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        guard fileList.item(index) != nil else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        try deleteCanvas(index: index)
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
        fileList.update(currentFileItem(thumbnail: thumbnail))
        fileList.sortItems()

        showToast(.success)
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
        let textures = try? await dependencies.documentsTextureDataRepository.duplicatedTextures(
            undoableTextureLayers.layers.map { $0.id },
            textureSize: undoableTextureLayers.textureSize,
            device: device
        )
        textures?.forEach { texture in
            undoableTextureLayers.updateLayerThumbnail(texture.0, thumbnail: texture.1.makeThumbnail())
        }
    }
}
