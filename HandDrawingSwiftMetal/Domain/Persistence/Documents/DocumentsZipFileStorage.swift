//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

private enum DocumentsZipFileStorageStaging {
    static let defaultRootName = "TmpFolder"
}

/// Zip archives in the Documents directory: zip/unzip session workflows and related file operations.
/// Each session uses a disposable staging directory under the system temp folder.
@MainActor
final class DocumentsZipFileStorage {

    private let fileManager: FileManaging
    private let zipHandler: ZipHandling

    /// Parent of per-session staging directories (`UUID` each).
    let stagingRootURL: URL

    init(
        fileManager: FileManaging,
        zipHandler: ZipHandling? = nil,
        stagingRootName: String = DocumentsZipFileStorageStaging.defaultRootName
    ) {
        self.fileManager = fileManager
        self.zipHandler = zipHandler ?? ZipHandler(fileManager: fileManager)
        let sanitizedRootName = Self.sanitizedStagingRootName(stagingRootName)
        self.stagingRootURL = fileManager.temporaryDirectory
            .appendingPathComponent(sanitizedRootName)
    }

    /// Stages files under a temp directory, zips them to `dst`, then removes the staging directory.
    func withZippedContents(
        to dst: URL,
        _ operation: (_ stagingDirectory: URL) async throws -> Void
    ) async throws {
        try await withStagingDirectory { stagingDirectory in
            try await operation(stagingDirectory)
            let fileURLs = try fileManager.contentsOfDirectory(
                at: stagingDirectory,
                includingPropertiesForKeys: nil
            )
            let fileName = dst.lastPathComponent
            let tempZipURL = stagingDirectory.appendingPathComponent(fileName)
            try zipHandler.zip(sourceURLs: fileURLs, to: tempZipURL)
            try fileManager.overwriteItem(src: tempZipURL, dst: dst)
        }
    }

    /// Unzips `src` into a temp staging directory, runs `operation`, then removes the staging directory.
    func withUnzippedContents<T>(
        from src: URL,
        _ operation: (_ stagingDirectory: URL) async throws -> T
    ) async throws -> T {
        try await withStagingDirectory { stagingDirectory in
            try await zipHandler.unzip(
                sourceURL: src,
                to: stagingDirectory,
                priority: .high
            )
            return try await operation(stagingDirectory)
        }
    }

    func removeFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    func renameFile(src: URL, dst: URL) throws {
        if fileManager.fileExists(atPath: dst.path),
            // fileExists does not distinguish letter case, so skip remove when
            // only the case differs; otherwise the source file would be deleted.
            src.path.lowercased() != dst.path.lowercased()
        {
            try fileManager.removeItem(at: dst)
        }
        try fileManager.moveItem(at: src, to: dst)
    }
}

private extension DocumentsZipFileStorage {

    static func sanitizedStagingRootName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = URL.sanitizedName(trimmed)
        return sanitized.isEmpty ? DocumentsZipFileStorageStaging.defaultRootName : sanitized
    }

    func withStagingDirectory<T>(
        _ operation: (_ stagingDirectory: URL) async throws -> T
    ) async throws -> T {
        let stagingDirectory = stagingRootURL.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
        defer { try? removeFile(at: stagingDirectory) }

        return try await operation(stagingDirectory)
    }
}
