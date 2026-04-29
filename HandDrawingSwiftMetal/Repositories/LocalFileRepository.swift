//
//  LocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/10/25.
//

import Foundation

/// Manages local file operations
final class LocalFileRepository: LocalFileRepositoryProtocol {

    /// URL of the directory for storing files
    let workingDirectoryURL: URL

    init(workingDirectoryURL: URL) {
        self.workingDirectoryURL = workingDirectoryURL
    }
}

extension LocalFileRepository {

    func createWorkingDirectory() throws -> URL {
        try FileManager.createNewDirectory(workingDirectoryURL)
        return workingDirectoryURL
    }

    func removeWorkingDirectory() throws {
        try FileManager.default.removeItem(at: workingDirectoryURL)
    }

    func zipWorkingDirectory(
        to zipFileURL: URL
    ) throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: workingDirectoryURL,
            includingPropertiesForKeys: nil
        )

        let fileName = zipFileURL.lastPathComponent
        let tempZipURL = workingDirectoryURL.appendingPathComponent(fileName)

        try FileOutput.zip(
            sourceURLs: fileURLs,
            to: tempZipURL
        )

        try moveFiles(from: tempZipURL, to: zipFileURL)
    }

    func unzipToWorkingDirectory(
        from zipFileURL: URL
    ) async throws {
        try await FileInput.unzip(
            sourceURL: zipFileURL,
            to: workingDirectoryURL,
            priority: .high
        )
    }
}

extension LocalFileRepository {

    private func moveFiles(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
