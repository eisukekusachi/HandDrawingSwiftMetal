//
//  MockLocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/29.
//

import Foundation

struct MockLocalFileRepository: LocalFileRepositoryProtocol, @unchecked Sendable {
    let workingDirectoryURL: URL

    init() {
        self.workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UT_FileCoordinator_WorkingDirectory_\(UUID().uuidString)")
    }

    @discardableResult
    func createWorkingDirectory() throws -> URL {
        // No-op: return a stable temporary URL (do not touch disk).
        return workingDirectoryURL
    }

    func removeWorkingDirectory() throws {
        // No-op
    }

    func zipWorkingDirectory(to zipFileURL: URL) throws {
        // No-op
    }

    func unzipToWorkingDirectory(from zipFileURL: URL) async throws {
        // No-op
    }
}
