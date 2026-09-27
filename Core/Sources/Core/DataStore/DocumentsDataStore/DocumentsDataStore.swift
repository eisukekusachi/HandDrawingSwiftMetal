//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

/// Documents-directory zip I/O. Domain-agnostic: no project / texture / palette knowledge.
@MainActor
public final class DocumentsDataStore {

    private let fileManager: FileManaging
    private let localFileRepository: LocalFileRepositoryProtocol

    public init(
        fileManager: FileManaging = FileManagerWrapper(),
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
