//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import CanvasView
import Combine
import FileView
import TextureLayerView
import UIKit

extension HandDrawingViewModel {

    var zipFileURL: URL {
        FileManager.zipFileURL(
            projectName: project.currentProjectName,
            suffix: fileList.fileSuffix
        )
    }

    /// Clears the canvas, assigns a new file name, and saves so the file list gains an item.
    func newCanvas(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        activityIndicatorSubject.send(true)
        defer { activityIndicatorSubject.send(false) }

        let targetURL = try URL.uniqueProjectURLInDocuments(
            fileName: fileName,
            fileSuffix: fileList.fileSuffix
        )

        try await initializeBlankCanvasContent(
            device: device,
            commandQueue: commandQueue
        )
        project.update(
            projectName: targetURL.baseName,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await saveProject(
            content: .init(
                thumbnail: nil,
                textureLayersState: textureLayersState,
                project: project,
                drawingTool: drawingTool,
                brushPalette: brushPalette,
                eraserPalette: eraserPalette
            ),
            to: targetURL
        )

        fileList.setItem(currentFileItem(thumbnail: nil))
        fileList.sortItems()

        return targetURL
    }

    /// Loads a saved canvas zip into the editor.
    func loadCanvas(
        device: MTLDevice?,
        zipFileURL: URL,
        completion: (() -> Void)?
    ) {
        Task { [weak self] in
            guard
                let `self`,
                let device
            else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.loadProject(
                    device: device,
                    from: zipFileURL
                ) { [weak self] workingDirectoryURL in
                    guard let `self` else { return }
                    try self.projectStorage.update(
                        directoryURL: workingDirectoryURL,
                        projectName: zipFileURL.baseName
                    )
                    try? self.drawingToolStorage.update(directoryURL: workingDirectoryURL)
                    try? self.brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                    try? self.eraserPaletteStorage.update(directoryURL: workingDirectoryURL)
                }

                let textures = try? await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
                    self.textureLayersState.layers.map { $0.id },
                    textureSize: textureLayersState.textureSize,
                    device: device
                )
                textures?.forEach { texture in
                    self.textureLayersState.updateThumbnail(texture.0, texture: texture.1)
                }

                completion?()

                self.toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                self.alertSubject.send(error)
            }
        }
    }

    /// Captures the current canvas state and writes it to a zip file.
    func saveCanvas(
        thumbnail: UIImage?,
        completion: (() -> Void)?,
        zipFileURL: URL
    ) {
        Task(priority: .userInitiated) { [weak self] in
            guard let `self` else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.saveProject(
                    content: .init(
                        thumbnail: thumbnail,
                        textureLayersState: self.textureLayersState,
                        project: self.project,
                        drawingTool: self.drawingTool,
                        brushPalette: self.brushPalette,
                        eraserPalette: self.eraserPalette
                    ),
                    to: zipFileURL
                )

                self.fileList.setItem(self.currentFileItem(thumbnail: thumbnail))
                self.fileList.sortItems()

                completion?()

                self.toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                self.alertSubject.send(error)
            }
        }
    }

    /// Clears the open canvas in place and overwrites the same zip.
    func clearCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        activityIndicatorSubject.send(true)
        defer { activityIndicatorSubject.send(false) }

        try await initializeBlankCanvasContent(
            device: device,
            commandQueue: commandQueue
        )
        project.update(updatedAt: Date())

        try await saveProject(
            content: .init(
                thumbnail: nil,
                textureLayersState: textureLayersState,
                project: project,
                drawingTool: drawingTool,
                brushPalette: brushPalette,
                eraserPalette: eraserPalette
            ),
            to: zipFileURL
        )
        fileList.setItem(currentFileItem(thumbnail: nil))
        fileList.sortItems()
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
            oldName: oldTitle,
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

        try dependencies.localFileRepository.moveItem(at: oldFileURL, to: newFileURL)
        fileList.renameItem(title: oldTitle, newTitle: uniqueName)

        if oldFileURL == zipFileURL {
            project.update(
                projectName: uniqueName,
                updatedAt: Date()
            )
        }

        return uniqueName
    }

    /// Removes a saved file from disk and the file list.
    func deleteCanvas(index: Int) throws {
        guard let item = fileList.item(index) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        try dependencies.localFileRepository.removeItem(at: item.fileURL)
        fileList.deleteItem(title: item.title)
    }
}

private extension HandDrawingViewModel {

    func saveProject(
        content: ProjectSaveContent,
        to zipFileURL: URL
    ) async throws {
        defer {
            try? dependencies.localFileRepository.removeWorkingDirectory()
        }
        let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()

        try await writeCanvasToWorkingDirectory(
            textureLayersState: content.textureLayersState,
            thumbnail: content.thumbnail,
            to: workingDirectoryURL
        )

        try DrawingToolArchiveModel(content.drawingTool).write(in: workingDirectoryURL)
        try BrushPaletteArchiveModel(content.brushPalette).write(in: workingDirectoryURL)
        try EraserPaletteArchiveModel(content.eraserPalette).write(in: workingDirectoryURL)
        try ProjectArchiveModel(content.project).write(in: workingDirectoryURL)

        try dependencies.localFileRepository.zipWorkingDirectory(to: zipFileURL)
    }

    func loadProject(
        device: MTLDevice,
        from zipFileURL: URL,
        action: (URL) async throws -> Void
    ) async throws {
        defer {
            try? dependencies.localFileRepository.removeWorkingDirectory()
        }
        let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()

        try await dependencies.localFileRepository.unzipToWorkingDirectory(from: zipFileURL)

        try await loadCanvasFromWorkingDirectory(
            device: device,
            from: workingDirectoryURL
        )

        try await action(workingDirectoryURL)
    }

    func writeCanvasToWorkingDirectory(
        textureLayersState: TextureLayersState,
        thumbnail: UIImage?,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            try thumbnail?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent(thumbnailFileName)
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

    func loadCanvasFromWorkingDirectory(
        device: MTLDevice,
        from workingDirectoryURL: URL
    ) async throws {
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let newTextureLayers: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        guard try await dependencies.textureLayersDocumentsRepository.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: newTextureLayers,
            device: device
        ) else {
            return
        }

        textureLayersState.update(newTextureLayers)
    }

    /// Clears the canvas texture and resets drawing tool / palettes.
    func initializeBlankCanvasContent(
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
}
