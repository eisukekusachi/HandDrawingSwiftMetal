//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

/// Manages temporary working-directory file operations for Documents zip I/O.
public final class LocalFileRepository: LocalFileRepositoryProtocol, @unchecked Sendable {

    public let workingDirectoryURL: URL

    private let fileManager: FileManaging
    private let zipHandler: ZipHandling

    public init(
        workingDirectoryURL: URL,
        fileManager: FileManaging = FileManagerWrapper(),
        zipHandler: ZipHandling? = nil
    ) {
        self.workingDirectoryURL = workingDirectoryURL
        self.fileManager = fileManager
        self.zipHandler = zipHandler ?? ZipHandler(fileManager: fileManager)
    }

    public func createWorkingDirectory() throws -> URL {
        if fileManager.fileExists(atPath: workingDirectoryURL.path) {
            try fileManager.removeItem(at: workingDirectoryURL)
        }
        try fileManager.createDirectory(
            at: workingDirectoryURL,
            withIntermediateDirectories: true
        )
        return workingDirectoryURL
    }

    public func removeWorkingDirectory() throws {
        try fileManager.removeItem(at: workingDirectoryURL)
    }

    public func zipWorkingDirectory(to zipFileURL: URL) throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: workingDirectoryURL,
            includingPropertiesForKeys: nil
        )
        let fileName = zipFileURL.lastPathComponent
        let tempZipURL = workingDirectoryURL.appendingPathComponent(fileName)
        try zipHandler.zip(sourceURLs: fileURLs, to: tempZipURL)
        try moveItem(at: tempZipURL, to: zipFileURL)
    }

    public func unzipToWorkingDirectory(from zipFileURL: URL) async throws {
        try await zipHandler.unzip(
            sourceURL: zipFileURL,
            to: workingDirectoryURL,
            priority: .high
        )
    }

    public func removeItem(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }
}
