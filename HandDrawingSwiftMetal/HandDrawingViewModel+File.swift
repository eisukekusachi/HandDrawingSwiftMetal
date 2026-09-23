//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import FileView
import Metal
import UIKit

extension HandDrawingViewModel {

    /// Scans Documents for zip files and refreshes the file list.
    func setupFileList() async {
        let fileURLs = URL.documents.allFileURLs(suffix: fileList.fileSuffix)
        let needsUnzip = fileURLs.contains { url in
            fileList.index(fileURL: url) == nil
        }

        if needsUnzip {
            showActivityIndicator(true)
        }
        defer {
            if needsUnzip {
                showActivityIndicator(false)
            }
        }

        await fileList.loadItems(from: fileURLs) { [weak self] zipFileURL in
            guard let self else { return nil }
            do {
                defer { try? dependencies.localFileRepository.removeWorkingDirectory() }
                let workingDirectoryURL = try dependencies.localFileRepository.createWorkingDirectory()
                try await dependencies.localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                let projectMetaData = try ProjectArchiveModel(in: workingDirectoryURL)
                let thumbnailURL = workingDirectoryURL.appendingPathComponent(thumbnailFileName)
                let thumbnailData = try? Data(contentsOf: thumbnailURL)

                return FileItem(
                    createdAt: projectMetaData.createdAt,
                    updatedAt: projectMetaData.updatedAt,
                    thumbnail: thumbnailData.flatMap(UIImage.init(data:)),
                    fileURL: zipFileURL
                )
            } catch {
                Logger.error(error)
                return nil
            }
        }
    }

    /// Creates a new canvas file, loads it, and asks the view to refresh.
    func createFile(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async {
        showActivityIndicator(true)
        defer { showActivityIndicator(false) }

        do {
            let zipFileURL = try await newCanvas(
                fileName: fileName,
                device: device,
                commandQueue: commandQueue
            )
            try await loadCanvas(
                device: device,
                zipFileURL: zipFileURL
            )
            showToast(.success)
            initializeCanvasRequestSubject.send(
                .init(dismissFileView: true)
            )
        } catch {
            showError(error)
        }
    }

    /// Renames a file in the list. Returns the stored title, or `nil` on failure.
    func renameFile(index: Int, newName: String) -> String? {
        do {
            return try renameCanvas(index: index, newName: newName)
        } catch {
            showError(error)
            return nil
        }
    }

    /// Deletes a saved file, or clears the open canvas when that file is selected.
    func deleteFile(
        index: Int,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async {
        showActivityIndicator(true)
        defer { showActivityIndicator(false) }

        do {
            guard let item = fileList.item(index) else {
                throw NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Invalid Value")
                )
            }

            if item.fileURL == currentZipFileURL {
                try await clearCanvas(
                    device: device,
                    commandQueue: commandQueue
                )
                initializeCanvasRequestSubject.send(
                    .init(
                        updateLayerList: true,
                        dismissFileView: true
                    )
                )
            } else {
                try deleteCanvas(index: index)
            }
        } catch {
            showError(error)
        }
    }

    /// Loads a zip into the editor and asks the view to refresh.
    func loadFile(
        device: MTLDevice,
        zipFileURL: URL
    ) async {
        showActivityIndicator(true)
        defer { showActivityIndicator(false) }

        do {
            try await loadCanvas(
                device: device,
                zipFileURL: zipFileURL
            )
            showToast(.success)
            initializeCanvasRequestSubject.send(.init())
        } catch {
            showError(error)
        }
    }

    /// Saves the current canvas and shows success feedback.
    func saveFile(
        thumbnail: UIImage?,
        zipFileURL: URL
    ) async {
        showActivityIndicator(true)
        defer { showActivityIndicator(false) }

        do {
            try await saveCanvas(
                thumbnail: thumbnail,
                zipFileURL: zipFileURL
            )
            showToast(.success)
        } catch {
            showError(error)
        }
    }
}
