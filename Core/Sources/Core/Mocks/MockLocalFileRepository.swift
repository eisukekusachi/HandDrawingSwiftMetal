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

    @discardableResult
    public func createWorkingDirectory() throws -> URL {
        // No-op: return a stable temporary URL (do not touch disk).
        workingDirectoryURL
    }

    public func removeWorkingDirectory() throws {
        // No-op
    }

    public func zipWorkingDirectory(to zipFileURL: URL) throws {
        // No-op
    }

    public func unzipToWorkingDirectory(from zipFileURL: URL) async throws {
        // No-op
    }

    public func removeItem(at url: URL) throws {
        // No-op
    }

    public func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        // No-op
    }
}
