//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

/// Documents-directory zip I/O. Domain-agnostic: no project / texture / palette knowledge.
@MainActor
public final class DocumentsDataStore {

    private let fileManager: FileManaging
    let localFileRepository: LocalFileRepositoryProtocol

    public init(
        fileManager: FileManaging,
        localFileRepository: LocalFileRepositoryProtocol? = nil
    ) {
        self.fileManager = fileManager
        self.localFileRepository = localFileRepository ?? LocalFileRepository(
            workingDirectoryURL: fileManager.temporaryDirectory.appendingPathComponent("TmpFolder"),
            fileManager: fileManager
        )
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
            try localFileRepository.zipFile(from: workingDirectoryURL, to: zipFileURL)
        }
    }

    /// Unzips `zipFileURL` into a working directory, runs `operation`, then cleans up.
    public func withUnzippedContents<T>(
        from zipFileURL: URL,
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        try await withWorkingDirectory { workingDirectoryURL in
            try await localFileRepository.unzipFile(from: zipFileURL, to: workingDirectoryURL)
            return try await operation(workingDirectoryURL)
        }
    }

    public func removeFile(at url: URL) throws {
        try localFileRepository.removeFile(at: url)
    }

    public func renameFile(at srcURL: URL, to dstURL: URL) throws {
        try localFileRepository.renameFile(at: srcURL, to: dstURL)
    }
}

private extension DocumentsDataStore {
    private func withWorkingDirectory<T>(
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        let workingDirectoryURL = try localFileRepository.createSessionDirectory()
        defer { try? localFileRepository.removeFile(at: workingDirectoryURL) }

        return try await operation(workingDirectoryURL)
    }
}
