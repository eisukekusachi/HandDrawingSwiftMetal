//
//  Created by Eisuke Kusachi
//

import Foundation

/// Temporary working-directory file operations for zip I/O.
///
/// Each session uses a unique subdirectory under `workingDirectoryURL`,
/// so sessions can run in parallel without sharing one folder.
struct LocalFileIO: Sendable {

    let workingDirectoryURL: URL

    private let fileManager: FileManaging
    private let zipHandler: ZipHandling

    init(
        workingDirectoryURL: URL,
        fileManager: FileManaging,
        zipHandler: ZipHandling? = nil
    ) {
        self.workingDirectoryURL = workingDirectoryURL
        self.fileManager = fileManager
        self.zipHandler = zipHandler ?? ZipHandler(fileManager: fileManager)
    }

    func createSessionDirectory() throws -> URL {
        let sessionURL = workingDirectoryURL.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(
            at: sessionURL,
            withIntermediateDirectories: true
        )
        return sessionURL
    }

    func zipFile(from directoryURL: URL, to zipFileURL: URL) throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        let fileName = zipFileURL.lastPathComponent
        let tempZipURL = directoryURL.appendingPathComponent(fileName)
        try zipHandler.zip(sourceURLs: fileURLs, to: tempZipURL)
        try renameFile(at: tempZipURL, to: zipFileURL)
    }

    func unzipFile(from zipFileURL: URL, to directoryURL: URL) async throws {
        try await zipHandler.unzip(
            sourceURL: zipFileURL,
            to: directoryURL,
            priority: .high
        )
    }

    func removeFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func renameFile(at sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path),
            // fileExists does not distinguish letter case, so skip remove when
            // only the case differs; otherwise the source file would be deleted.
            sourceURL.path.lowercased() != destinationURL.path.lowercased()
        {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }
}
