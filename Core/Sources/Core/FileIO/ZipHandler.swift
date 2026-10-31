//
//  Created by Eisuke Kusachi
//

import Foundation
import ZIPFoundation

public protocol ZipHandling: Sendable {
    func zip(sourceURLs: [URL], to zipFileURL: URL) throws
    func unzip(sourceURL: URL, to destinationURL: URL, priority: TaskPriority?) async throws
}

/// Production implementation backed by ZIPFoundation.
public struct ZipHandler: ZipHandling {
    private let fileManager: FileManaging

    public init(fileManager: FileManaging) {
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
