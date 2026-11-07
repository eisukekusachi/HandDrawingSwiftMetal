//
//  Created by Eisuke Kusachi
//

import Foundation

/// Zip archives in the Documents directory: paths, uniqueness for names, and zip/unzip session workflows.
/// Uses a temporary directory under the system temp folder for each session.
@MainActor
public final class DocumentsZipFileStorage {

    private let fileManager: FileManaging
    private let zipHandler: ZipHandling

    /// Root for session subfolders (`UUID` each) used while zipping or unzipping.
    let zipSessionsWorkingRootURL: URL

    public init(
        fileManager: FileManaging,
        zipHandler: ZipHandling? = nil,
        zipSessionsDirectoryName: String = "TmpFolder"
    ) {
        self.fileManager = fileManager
        self.zipHandler = zipHandler ?? ZipHandler(fileManager: fileManager)
        self.zipSessionsWorkingRootURL = fileManager.temporaryDirectory
            .appendingPathComponent(zipSessionsDirectoryName)
    }

    /// URL of a project zip in Documents for the given project name and file suffix.
    public func zipFileURL(projectName: String, suffix: String) -> URL {
        guard !suffix.isEmpty else {
            return fileManager.documentsDirectory.appendingPathComponent(projectName)
        }
        return fileManager.documentsDirectory.appendingPathComponent(projectName + "." + suffix)
    }

    /// Returns a unique zip URL in Documents by appending `_2`, `_3`, ... when needed.
    public func uniqueZipFileURL(
        fileName: String,
        suffix: String,
        excludeURL: URL? = nil
    ) throws -> URL {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else {
            throw NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Please enter a file name", bundle: .module)
            )
        }

        let baseName = URL.sanitizedName(trimmedFileName)
        guard !baseName.isEmpty else {
            throw NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid Value", bundle: .module)
            )
        }

        var candidateURL = zipFileURL(projectName: baseName, suffix: suffix)
        var suffixIndex = 2
        while fileManager.fileExists(atPath: candidateURL.path),
              excludeURL.map({ $0.path.lowercased() != candidateURL.path.lowercased() }) ?? true
        {
            candidateURL = zipFileURL(projectName: "\(baseName)_\(suffixIndex)", suffix: suffix)
            suffixIndex += 1
        }
        return candidateURL
    }

    /// Creates a working directory, runs `operation` to write files, zips them to `zipFileURL`, then cleans up.
    public func withZippedContents(
        to zipFileURL: URL,
        _ operation: (_ workingDirectoryURL: URL) async throws -> Void
    ) async throws {
        try await withWorkingDirectory { workingDirectoryURL in
            try await operation(workingDirectoryURL)
            try zipDirectory(from: workingDirectoryURL, to: zipFileURL)
        }
    }

    /// Unzips `zipFileURL` into a working directory, runs `operation`, then cleans up.
    public func withUnzippedContents<T>(
        from zipFileURL: URL,
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        try await withWorkingDirectory { workingDirectoryURL in
            try await unzipFile(from: zipFileURL, to: workingDirectoryURL)
            return try await operation(workingDirectoryURL)
        }
    }

    public func removeFile(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func renameFile(at srcURL: URL, to dstURL: URL) throws {
        try renameAcrossVolumesPreservingCaseIfNeeded(at: srcURL, to: dstURL)
    }
}

private extension DocumentsZipFileStorage {

    func withWorkingDirectory<T>(
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        let workingDirectoryURL = try createSessionDirectory()
        defer { try? removeFile(at: workingDirectoryURL) }

        return try await operation(workingDirectoryURL)
    }

    func createSessionDirectory() throws -> URL {
        let sessionURL = zipSessionsWorkingRootURL.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(
            at: sessionURL,
            withIntermediateDirectories: true
        )
        return sessionURL
    }

    func zipDirectory(from directoryURL: URL, to zipFileURL: URL) throws {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        let fileName = zipFileURL.lastPathComponent
        let tempZipURL = directoryURL.appendingPathComponent(fileName)
        try zipHandler.zip(sourceURLs: fileURLs, to: tempZipURL)
        try renameAcrossVolumesPreservingCaseIfNeeded(at: tempZipURL, to: zipFileURL)
    }

    func unzipFile(from zipFileURL: URL, to directoryURL: URL) async throws {
        try await zipHandler.unzip(
            sourceURL: zipFileURL,
            to: directoryURL,
            priority: .high
        )
    }

    func renameAcrossVolumesPreservingCaseIfNeeded(at sourceURL: URL, to destinationURL: URL) throws {
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
