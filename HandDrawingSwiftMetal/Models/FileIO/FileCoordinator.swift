//
//  FileCoordinator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/24.
//

import Combine
import Foundation
import Metal
import TextureLayerView
import UIKit

@MainActor
final class FileCoordinator: ObservableObject {

    /// Zips in Documents (for `FileView`) with thumbnails and project metadata in memory.
    @Published private(set) var fileList: [LocalFileItem] = []

    /// Suffix for project files in Documents (e.g. `zip`), from `ProjectConfiguration`.
    private(set) var fileSuffix: String = ""

    private let thumbnailName: String = "thumbnail.png"

    private let dependencies: HandDrawingViewDependencies

    init(dependencies: HandDrawingViewDependencies) {
        self.dependencies = dependencies
    }

    /// Replaces `fileList` from zips in Documents (metadata + thumbnails). Uses `fileSuffix` from configuration.
    func setupFileList(
        configuration: ProjectConfiguration
    ) async {
        self.fileSuffix = configuration.fileSuffix

        var fileNames: [String] = []

        URL.documents.allFileURLs(suffix: configuration.fileSuffix).map {
            $0.lastPathComponent
        }.forEach {
            fileNames.append($0)
        }

        var items: [LocalFileItem] = []

        for fileName in fileNames {
            do {
                defer { try? dependencies.localFileRepository.removeWorkingDirectory() }
                let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()

                let zipFileURL = URL.documents.appendingPathComponent(fileName)

                try await dependencies.localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                let projectMetaData: ProjectArchiveModel = try .init(
                    in: workingDirectoryURL
                )

                let thumbnailURL = workingDirectoryURL.appendingPathComponent(thumbnailName)
                let thumbnailData = try? Data(contentsOf: thumbnailURL)

                items.append(
                    .init(
                        title: zipFileURL.baseName,
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        thumbnail: thumbnailData.flatMap(UIImage.init(data:)),
                        fileURL: zipFileURL
                    )
                )

            } catch {
                // Old/externally-created zips may not contain `thumbnail.png`.
                // Missing thumbnails should not be treated as an error here.
                Logger.error(error)
            }
        }

        items.sort { $0.updatedAt > $1.updatedAt }
        fileList = items
    }

    func initializeStorageByRestoring(
        textureLayers: TextureLayersModel,
        device: MTLDevice
    ) throws {
        try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
            textureLayers: textureLayers,
            device: device
        )
    }

    func initializeStorage(
        textureLayers: TextureLayersModel,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: textureLayers,
            device: device,
            commandQueue: commandQueue
        )
    }
}

extension FileCoordinator {

    func saveProject(
        content: FileCoordinatorSaveContent,
        to zipFileURL: URL
    ) async throws {
        defer {
            try? dependencies.localFileRepository.removeWorkingDirectory()
        }
        let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()

        try await saveCanvasToWorkingDirectory(
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
        device: MTLDevice?,
        textureLayersState: TextureLayersState,
        from zipFileURL: URL,
        action: (URL) async throws -> Void
    ) async throws {
        guard let `device` else { return }
        defer {
            try? dependencies.localFileRepository.removeWorkingDirectory()
        }
        let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()

        try await dependencies.localFileRepository.unzipToWorkingDirectory(from: zipFileURL)

        try await loadCanvasFromWorkingDirectory(
            device: device,
            from: workingDirectoryURL,
            into: textureLayersState
        )

        try await action(
            workingDirectoryURL
        )
    }
}

extension FileCoordinator {
    func upsertFileList(_ file: LocalFileItem) {
        var items = fileList
        if let index = items.firstIndex(where: { $0.title == file.title }) {
            items[index] = file
        } else {
            items.append(file)
        }
        items.sort { $0.updatedAt > $1.updatedAt }
        fileList = items
    }

    /// Renames on disk; if the renamed file is the one currently open, updates `project`; syncs `fileList`.
    @discardableResult
    func renameFile(
        oldFileURL: URL,
        newName: String,
        currentOpenFileURL: URL,
        project: ProjectData
    ) throws -> URL {
        guard
            let index = fileList.firstIndex(where: { $0.fileURL == oldFileURL })
        else { return oldFileURL }

        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? oldFileURL.baseName : trimmedName

        let newFileURL = URL.uniqueURL(
            baseName: baseName,
            fileSuffix: fileSuffix,
            excludeURL: oldFileURL
        )

        if newFileURL == oldFileURL {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "The file name is the same as the current name")
            )
            throw error
        }

        try FileManager.default.moveItem(at: oldFileURL, to: newFileURL)

        let items = fileList
        items[index].update(
            title: newFileURL.baseName,
            fileURL: newFileURL,
            updatedAt: Date()
        )
        fileList = items

        return newFileURL
    }

    /// Removes the zip in Documents and drops it from `fileList` (cannot delete the open file).
    func deleteFile(
        fileURL: URL,
        currentOpenFileURL: URL
    ) throws {
        if fileURL == currentOpenFileURL {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "The currently open file cannot be deleted")
            )
            throw error
        }

        try FileManager.default.removeItem(at: fileURL)

        var items = fileList
        items.removeAll { $0.fileURL == fileURL }
        fileList = items
    }

    func currentFileItem(
        for project: ProjectData,
        thumbnail: UIImage?
    ) -> LocalFileItem {
        .init(
            title: project.currentProjectName,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: FileManager.zipFileURL(
                projectName: project.currentProjectName,
                suffix: fileSuffix
            )
        )
    }
}

private extension FileCoordinator {
    func fileItem(
        workingDirectoryURL: URL,
        fileName: String
    ) async throws -> LocalFileItem {
        let zipFileURL = URL.documents.appendingPathComponent(fileName)

        try await dependencies.localFileRepository.unzipToWorkingDirectory(
            from: zipFileURL
        )

        let projectMetaData: ProjectArchiveModel = try .init(
            in: workingDirectoryURL
        )

        let thumbnailData = try Data(
            contentsOf: workingDirectoryURL.appendingPathComponent(thumbnailName)
        )

        return .init(
            title: zipFileURL.baseName,
            createdAt: projectMetaData.createdAt,
            updatedAt: projectMetaData.updatedAt,
            thumbnail: UIImage(data: thumbnailData),
            fileURL: zipFileURL
        )
    }

    func saveCanvasToWorkingDirectory(
        textureLayersState: TextureLayersState,
        thumbnail: UIImage?,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            try thumbnail?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent(thumbnailName)
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
        from workingDirectoryURL: URL,
        into textureLayersState: TextureLayersState
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
}
