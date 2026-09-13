//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import CanvasView
import Combine
import TextureLayerView
import UIKit

extension HandDrawingViewModel {

    var zipFileURL: URL {
        FileManager.zipFileURL(
            projectName: project.currentProjectName,
            suffix: fileCoordinator.fileSuffix
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
            fileSuffix: fileCoordinator.fileSuffix
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

        try await fileCoordinator.saveProject(
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

        fileCoordinator.upsertFileList(
            currentFileItem(thumbnail: nil)
        )

        fileCoordinator.sortFileList()

        return targetURL
    }

    /// Clears the canvas texture and resets drawing tool / palettes.
    private func initializeBlankCanvasContent(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let newTextureLayersState: TextureLayersModel = .init(textureSize: textureLayersState.textureSize)

        try await fileCoordinator.initializeStorage(
            textureLayers: newTextureLayersState,
            device: device,
            commandQueue: commandQueue
        )
        textureLayersState.update(newTextureLayersState)

        drawingToolStorage.initializeData()
        brushPalette.initializeData()
        eraserPalette.initializeData()
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
                try await self.fileCoordinator.loadProject(
                    device: device,
                    textureLayersState: textureLayersState,
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
                try await self.fileCoordinator.saveProject(
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

        try await fileCoordinator.saveProject(
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
        fileCoordinator.upsertFileList(
            currentFileItem(thumbnail: nil)
        )
        fileCoordinator.sortFileList()
    }

    /// Renames a saved file on disk and updates the file list.
    @discardableResult
    func renameCanvas(
        index: Int,
        newName: String,
        currentOpenFileURL: URL
    ) throws -> URL {
        guard
            let item = fileCoordinator.item(index),
            let index = fileCoordinator.index(url: item.fileURL)
        else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        let oldFileURL = item.fileURL

        let normalizedName = URL.normalizedName(
            oldName: oldFileURL.baseName,
            newName: newName
        )

        let newFileURL = URL.uniqueURL(
            baseName: normalizedName,
            fileSuffix: fileCoordinator.fileSuffix,
            excludeURL: oldFileURL
        )

        try fileCoordinator.renameFile(
            index: index,
            oldFileURL: oldFileURL,
            newFileURL: newFileURL
        )

        if oldFileURL == currentOpenFileURL {
            project.update(
                projectName: newFileURL.baseName,
                updatedAt: Date()
            )
        }

        return newFileURL
    }

    /// Removes a saved file from disk and the file list.
    func deleteCanvas(fileURL: URL) throws {
        try fileCoordinator.deleteFile(fileURL: fileURL)
    }
}
