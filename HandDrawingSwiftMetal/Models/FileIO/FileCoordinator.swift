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

    private let dependencies: HandDrawingViewDependencies
    private var localFile: LocalFileRepositoryProtocol { dependencies.localFileRepository }
    private var textureDocuments: TextureLayersDocumentsRepositoryProtocol { dependencies.textureLayersDocumentsRepository }
    private let thumbnailName: String = "thumbnail.png"

    init(dependencies: HandDrawingViewDependencies) {
        self.dependencies = dependencies
    }

    func applyProjectFileConfiguration(_ configuration: ProjectConfiguration) {
        fileSuffix = configuration.fileSuffix
    }

    // MARK: - Open project: Documents path & list row

    /// `projectName` with optional `projectName.ext` when `fileSuffix` is non-empty (matches `HandDrawingViewModel`’s old behavior).
    func preferredFileNameInDocuments(forProjectName projectName: String) -> String {
        if fileSuffix.isEmpty {
            return projectName
        }
        return projectName + "." + fileSuffix
    }

    /// URL of the zip (or project file) for the current project name in Documents.
    func documentURLForProjectName(_ projectName: String) -> URL {
        if fileSuffix.isEmpty {
            return URL.documents.appendingPathComponent(projectName)
        }
        return FileManager.documentsFileURL(projectName: projectName, suffix: fileSuffix)
    }

    func localFileItem(for project: ProjectData, thumbnail: UIImage?) -> LocalFileItem {
        let name = preferredFileNameInDocuments(forProjectName: project.projectName)
        return .init(
            title: project.projectName,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: URL.documents.appendingPathComponent(name)
        )
    }

    /// A `Documents` URL for a new project file that does not exist yet. Appends `_2`, `_3`, … on name collision.
    /// - Parameter proposedBaseName: File name without extension (e.g. `MySketch`).
    func makeUniqueNewProjectDocumentURL(proposedBaseName: String) throws -> URL {
        let trimmed = proposedBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "HandDrawingSwiftMetal",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Please enter a file name."]
            )
        }
        let base = Self.sanitizedProjectBaseName(trimmed)
        guard !base.isEmpty else {
            throw NSError(
                domain: "HandDrawingSwiftMetal",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid file name."]
            )
        }

        func makeURL(_ name: String) -> URL {
            if fileSuffix.isEmpty {
                return URL.documents.appendingPathComponent(name)
            }
            return FileManager.documentsFileURL(projectName: name, suffix: fileSuffix)
        }

        var candidateName = base
        var candidateURL = makeURL(candidateName)
        var suffixIndex = 2
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateName = "\(base)_\(suffixIndex)"
            candidateURL = makeURL(candidateName)
            suffixIndex += 1
        }
        return candidateURL
    }

    private static func sanitizedProjectBaseName(_ raw: String) -> String {
        var s = raw
        for ch in ["/", "\\", ":", "?", "%", "*", "|", "\"", "<", ">"] {
            s = s.replacingOccurrences(of: ch, with: "_")
        }
        return s
    }

    // MARK: - Texture layers (document repository)

    func restorePersistedTextureLayersInDocuments(
        _ data: TextureLayersModel,
        device: MTLDevice
    ) throws {
        try textureDocuments.restoreStorageFromWorkingDirectory(
            textureLayers: data,
            device: device
        )
    }

    func createAndInitializeTextureLayers(
        device: MTLDevice,
        textureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> TextureLayersModel {
        let data = TextureLayersModel(textureSize: textureSize)
        do {
            try await textureDocuments.initializeStorage(
                textureLayers: data,
                device: device,
                commandQueue: commandQueue
            )
        } catch {
            fatalError("Failed to initialize storage")
        }
        return data
    }

    /// Reset canvas: new in-memory layer stack and backing Metal storage.
    func createNewTextureLayers(
        device: MTLDevice,
        textureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async throws -> TextureLayersModel {
        let data = TextureLayersModel(textureSize: textureSize)
        try await textureDocuments.initializeStorage(
            textureLayers: data,
            device: device,
            commandQueue: commandQueue
        )
        return data
    }

    // MARK: - Unzipped / temp working directory (before zip or after unpack)

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
                try await textureDocuments.copyTexture(
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
        into state: TextureLayersState
    ) async throws {
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let data: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        guard try await textureDocuments.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: data,
            device: device
        ) else {
            return
        }

        state.update(data)
    }

    // MARK: - Project zip session metadata (in working directory before `zipWorkingDirectory`)

    func writeSessionMetadataToWorkingDirectory(
        _ workingDirectoryURL: URL,
        drawingTool: DrawingTool,
        brushPalette: BrushPalette,
        eraserPalette: EraserPalette,
        project: ProjectData
    ) throws {
        try DrawingToolArchiveModel(drawingTool).write(in: workingDirectoryURL)
        try BrushPaletteArchiveModel(brushPalette).write(in: workingDirectoryURL)
        try EraserPaletteArchiveModel(eraserPalette).write(in: workingDirectoryURL)
        try ProjectArchiveModel(project).write(in: workingDirectoryURL)
    }

    // MARK: - Zip save / load (working directory)

    /// Creates a working directory, runs `work` to write project data, then zips it to `zipFileURL`. Removes the working directory when done.
    func saveZippedProject(
        to zipFileURL: URL,
        work: (URL) async throws -> Void
    ) async throws {
        defer { try? localFile.removeWorkingDirectory() }
        try localFile.createWorkingDirectory()
        let working = localFile.workingDirectoryURL
        try await work(working)
        try localFile.zipWorkingDirectory(to: zipFileURL)
    }

    /// Unzips `zipFileURL` into a working directory, then runs `work`. Removes the working directory when done.
    func loadUnzippedProject(
        from zipFileURL: URL,
        work: (URL) async throws -> Void
    ) async throws {
        defer { try? localFile.removeWorkingDirectory() }
        try localFile.createWorkingDirectory()
        try await localFile.unzipToWorkingDirectory(from: zipFileURL)
        let working = localFile.workingDirectoryURL
        try await work(working)
    }

    // MARK: - File list (Documents / project zips)

    /// Replaces `fileList` from zips in Documents (metadata + thumbnails). Uses `fileSuffix` from configuration.
    func refreshFileListFromDocuments() async {
        let configuredSuffix = fileSuffix
        var fileNames: [String] = []

        URL.documents.allFileURLs(suffix: configuredSuffix).map {
            $0.lastPathComponent
        }.forEach {
            fileNames.append($0)
        }

        var items: [LocalFileItem] = []

        for fileName in fileNames {
            do {
                defer { try? localFile.removeWorkingDirectory() }
                try localFile.createWorkingDirectory()

                let workingDirectoryURL = localFile.workingDirectoryURL
                let zipFileURL = URL.documents.appendingPathComponent(fileName)

                try await localFile.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                let projectMetaData: ProjectArchiveModel = try .init(
                    in: workingDirectoryURL
                )

                let data = try Data(
                    contentsOf: workingDirectoryURL.appendingPathComponent(thumbnailName)
                )

                let title = zipFileURL.deletingPathExtension().lastPathComponent

                items.append(
                    .init(
                        title: title,
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        thumbnail: UIImage(data: data),
                        fileURL: zipFileURL
                    )
                )
            } catch {
                Logger.error(error)
            }
        }

        items.sort { $0.updatedAt > $1.updatedAt }
        fileList = items
    }

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

    func renameFileListItem(
        oldFileURL: URL,
        newFileURL: URL,
        newTitle: String
    ) {
        guard let index = fileList.firstIndex(where: { $0.fileURL == oldFileURL }) else { return }
        let items = fileList
        items[index].update(
            title: newTitle,
            fileURL: newFileURL,
            updatedAt: Date()
        )
        fileList = items
    }

    func removeFileItem(fileURL: URL) {
        var items = fileList
        items.removeAll { $0.fileURL == fileURL }
        fileList = items
    }

    // MARK: - FileView: rename / delete in Documents

    /// Renames on disk; if the renamed file is the one currently open, updates `project`; syncs `fileList`.
    @discardableResult
    func renameFileForFileView(
        oldFileURL: URL,
        newName: String,
        currentOpenFileURL: URL,
        project: ProjectData
    ) throws -> URL {
        let candidateURL = try renameProjectZipInDocuments(oldFileURL: oldFileURL, newName: newName)
        let candidateName = candidateURL.deletingPathExtension().lastPathComponent
        if oldFileURL == currentOpenFileURL {
            project.update(projectName: candidateName, updatedAt: Date())
        }
        renameFileListItem(
            oldFileURL: oldFileURL,
            newFileURL: candidateURL,
            newTitle: candidateName
        )
        return candidateURL
    }

    /// Removes the zip in Documents and drops it from `fileList` (cannot delete the open file).
    func deleteFileForFileView(
        fileURL: URL,
        currentOpenFileURL: URL
    ) throws {
        try deleteProjectZipInDocuments(
            fileURL: fileURL,
            currentOpenFileURL: currentOpenFileURL
        )
        removeFileItem(fileURL: fileURL)
    }

    /// Renames a project zip in Documents. If a file with the target name exists, appends `_2`, `_3`, …
    @discardableResult
    func renameProjectZipInDocuments(
        oldFileURL: URL,
        newName: String
    ) throws -> URL {
        try renameProjectZipInDocuments(oldFileURL: oldFileURL, newName: newName, fileSuffix: fileSuffix)
    }

    @discardableResult
    func renameProjectZipInDocuments(
        oldFileURL: URL,
        newName: String,
        fileSuffix: String
    ) throws -> URL {
        let ext: String
        if oldFileURL.pathExtension.isEmpty {
            ext = fileSuffix
        } else {
            ext = oldFileURL.pathExtension
        }

        func makeURL(_ name: String) -> URL {
            FileManager.documentsFileURL(projectName: name, suffix: ext)
        }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String
        if trimmed.isEmpty {
            baseName = oldFileURL.deletingPathExtension().lastPathComponent
        } else {
            baseName = trimmed
        }

        var candidateName = baseName
        var candidateURL = makeURL(candidateName)
        var suffixIndex = 2

        while FileManager.default.fileExists(atPath: candidateURL.path) && candidateURL != oldFileURL {
            candidateName = "\(baseName)_\(suffixIndex)"
            candidateURL = makeURL(candidateName)
            suffixIndex += 1
        }

        try FileManager.default.moveItem(at: oldFileURL, to: candidateURL)
        return candidateURL
    }

    /// Removes a project zip unless it is the one currently open.
    func deleteProjectZipInDocuments(
        fileURL: URL,
        currentOpenFileURL: URL
    ) throws {
        if fileURL == currentOpenFileURL {
            let error = NSError(
                domain: "HandDrawingSwiftMetal",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "The currently open file cannot be deleted."]
            )
            throw error
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
