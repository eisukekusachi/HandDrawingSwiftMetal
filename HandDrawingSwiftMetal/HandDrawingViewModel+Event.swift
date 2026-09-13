//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import FileView
import Foundation
import Metal

extension HandDrawingViewModel {
    /// Builds a package `FileList` snapshot from `fileCoordinator`.
    func makeFileList() -> FileList {
        .init(
            fileSuffix: fileCoordinator.fileSuffix,
            items: fileCoordinator.fileList.map { local in
                FileItem(
                    createdAt: local.createdAt,
                    updatedAt: local.updatedAt,
                    thumbnail: local.thumbnail,
                    fileURL: local.fileURL
                )
            }
        )
    }

    func onTapRenameFile(
        _ fileList: FileList,
        index: Int,
        newName: String
    ) -> String? {
        guard let item = fileList.item(index) else {
            showError(
                NSError(
                    title: String(localized: "Error"),
                    message: String(localized: "Invalid Value")
                )
            )
            return nil
        }

        do {
            let oldTitle = item.title
            let newURL = try renameCanvas(
                index: index,
                newName: newName,
                currentOpenFileURL: zipFileURL
            )
            fileList.renameItem(title: oldTitle, newTitle: newURL.baseName)
            return newURL.baseName
        } catch {
            showError(error)
            return nil
        }
    }

    /// Deletes a saved file, or clears the open canvas when that file is selected.
    /// - Returns: `true` when the open canvas was cleared and the UI should reinitialize.
    func onTapDeleteFile(
        _ fileList: FileList,
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

        if item.fileURL == zipFileURL {
            try await clearCanvas(
                device: device,
                commandQueue: commandQueue
            )
            if let local = fileCoordinator.fileList.first(where: { $0.fileURL == zipFileURL }) {
                fileList.setItem(
                    FileItem(
                        createdAt: local.createdAt,
                        updatedAt: local.updatedAt,
                        thumbnail: local.thumbnail,
                        fileURL: local.fileURL
                    )
                )
                fileList.sortItems()
            }
            return true
        }

        try deleteCanvas(fileURL: item.fileURL)
        fileList.deleteItem(title: item.title)
        return false
    }

    func onTapNewCanvas(
        _ fileList: FileList,
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        let zipFileURL = try await newCanvas(
            fileName: fileName,
            device: device,
            commandQueue: commandQueue
        )
        if let local = fileCoordinator.fileList.first(where: { $0.fileURL == zipFileURL }) {
            fileList.setItem(
                FileItem(
                    createdAt: local.createdAt,
                    updatedAt: local.updatedAt,
                    thumbnail: local.thumbnail,
                    fileURL: local.fileURL
                )
            )
            fileList.sortItems()
        }
        return zipFileURL
    }
}
