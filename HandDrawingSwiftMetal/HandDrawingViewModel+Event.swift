//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import FileView
import Foundation
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
}
