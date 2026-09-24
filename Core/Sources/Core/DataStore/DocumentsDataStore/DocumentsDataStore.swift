//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

/// Documents-directory zip I/O. Domain-agnostic: no project / texture / palette knowledge.
@MainActor
public final class DocumentsDataStore {

    private let localFileRepository: LocalFileRepositoryProtocol

    public init(
        localFileRepository: LocalFileRepositoryProtocol = LocalFileRepository(
            workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    ) {
        self.localFileRepository = localFileRepository
    }

    /// URL of a project zip in Documents for the given project name and file suffix.
    public func zipFileURL(projectName: String, suffix: String) -> URL {
        FileManager.zipFileURL(projectName: projectName, suffix: suffix)
    }

    /// Creates a fresh working directory, runs `operation`, then removes the working directory.
    public func withWorkingDirectory<T>(
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        defer {
            try? localFileRepository.removeWorkingDirectory()
        }
        let workingDirectoryURL = try localFileRepository.createWorkingDirectory()
        return try await operation(workingDirectoryURL)
    }

    /// Unzips `zipFileURL` into a fresh working directory, runs `operation`, then cleans up.
    public func withUnzippedContents<T>(
        from zipFileURL: URL,
        _ operation: (_ workingDirectoryURL: URL) async throws -> T
    ) async throws -> T {
        try await withWorkingDirectory { workingDirectoryURL in
            try await localFileRepository.unzipToWorkingDirectory(from: zipFileURL)
            return try await operation(workingDirectoryURL)
        }
    }

    /// Zips the current working directory to `zipFileURL`.
    /// Call only inside `withWorkingDirectory` / `withUnzippedContents`.
    public func zipWorkingDirectory(to zipFileURL: URL) throws {
        try localFileRepository.zipWorkingDirectory(to: zipFileURL)
    }

    public func removeItem(at url: URL) throws {
        try localFileRepository.removeItem(at: url)
    }

    public func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try localFileRepository.moveItem(at: srcURL, to: dstURL)
    }
}
