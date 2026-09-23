//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import FileView
import Foundation
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

    func onTapRenameFile(_ index: Int, _ newName: String) throws -> String {
        try renameCanvas(index: index, newName: newName)
    }

    /// Deletes a saved file, or clears the open canvas when that file is selected.
    /// - Returns: `true` when the open canvas was cleared and the UI should reinitialize.
    func onTapDeleteFile(
        index: Int,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> Bool {
        guard let item = fileList.item(index) else {
            showError(
                NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Invalid Value")
                )
            )
            return false
        }

        if item.fileURL == currentZipFileURL {
            try await clearCanvas(
                device: device,
                commandQueue: commandQueue
            )
            return true
        }

        try deleteCanvas(index: index)
        return false
    }

    func onTapNewCanvas(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        try await newCanvas(
            fileName: fileName,
            device: device,
            commandQueue: commandQueue
        )
    }
}
