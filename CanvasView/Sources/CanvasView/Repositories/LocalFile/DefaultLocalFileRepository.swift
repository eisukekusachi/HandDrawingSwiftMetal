//
//  DefaultLocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Combine
import Foundation

/// A repository responsible for handling local file operations
public final class DefaultLocalFileRepository: LocalFileRepository {

    /// The URL of the directory for storing temporary files
    public let workingDirectoryURL: URL

    init(workingDirectoryURL: URL) {
        self.workingDirectoryURL = workingDirectoryURL
    }
}

public extension DefaultLocalFileRepository {

    func createWorkingDirectory() throws {
        try FileManager.createNewDirectory(workingDirectoryURL)
    }

    func removeWorkingDirectory() {
        // Do nothing if directory deletion fails
        try? FileManager.default.removeItem(at: workingDirectoryURL)
    }

    /// Compresses the working directory contents into a ZIP file
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

        // Overwrite if a file with the same name exists
        try moveFiles(from: tempZipURL, to: zipFileURL)
    }

    /// Unzips a file into the working directory
    func unzipToWorkingDirectoryAsync(
        from zipFileURL: URL
    ) async throws -> URL {
        try FileInput.unzip(
            sourceURL: zipFileURL,
            to: workingDirectoryURL
        )
        return workingDirectoryURL
    }
}

extension DefaultLocalFileRepository {

    private func moveFiles(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
