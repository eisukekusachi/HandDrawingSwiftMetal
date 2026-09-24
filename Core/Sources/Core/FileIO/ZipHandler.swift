//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation
import ZIPFoundation

/// Zip / unzip used by LocalFileRepository. Swap for a mock in tests.
public protocol ZipHandling: Sendable {
    func zip(sourceURLs: [URL], to zipFileURL: URL) throws
    func unzip(sourceURL: URL, to destinationURL: URL, priority: TaskPriority?) async throws
}

/// Production implementation backed by ZIPFoundation.
public struct ZipHandler: ZipHandling {
    private let fileManager: FileManaging

    public init(fileManager: FileManaging = FileManagerWrapper()) {
        self.fileManager = fileManager
    }

    public func zip(sourceURLs: [URL], to zipFileURL: URL) throws {
        let archive = try Archive(url: zipFileURL, accessMode: .create)
        try sourceURLs.forEach { url in
            try archive.addEntry(
                with: url.lastPathComponent,
                fileURL: url,
                compressionMethod: .deflate
            )
        }
    }

    public func unzip(sourceURL: URL, to destinationURL: URL, priority: TaskPriority?) async throws {
        let fileManager = self.fileManager
        try await Task.detached(priority: priority) {
            try fileManager.unzipItem(at: sourceURL, to: destinationURL)
        }.value
    }
}
