//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public struct MockLocalFileRepository: LocalFileRepositoryProtocol, @unchecked Sendable {
    public let workingDirectoryURL: URL

    public init(
        workingDirectoryURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workingDirectory_\(UUID().uuidString)")
    ) {
        self.workingDirectoryURL = workingDirectoryURL
    }

    public func createSessionDirectory() throws -> URL {
        workingDirectoryURL
    }

    public func zipFile(from directoryURL: URL, to zipFileURL: URL) throws {
        // No-op
    }

    public func unzipFile(from zipFileURL: URL, to directoryURL: URL) async throws {
        // No-op
    }

    public func removeFile(at url: URL) throws {
        // No-op
    }

    public func renameFile(at sourceURL: URL, to destinationURL: URL) throws {
        // No-op
    }
}
