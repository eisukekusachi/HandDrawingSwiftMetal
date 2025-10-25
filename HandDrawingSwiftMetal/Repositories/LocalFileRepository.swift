//
//  LocalFileRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/10/25.
//

import Combine
import Foundation

/// A repository responsible for handling local file operations
public final class LocalFileRepository {

    /// The URL of the directory for storing temporary files
    private let workingDirectoryURL: URL

    init(workingDirectoryURL: URL) {
        self.workingDirectoryURL = workingDirectoryURL
    }
}

public extension LocalFileRepository {

    func createWorkingDirectory() throws -> URL {
        try FileManager.createNewDirectory(workingDirectoryURL)
        return workingDirectoryURL
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
}

extension LocalFileRepository {

    private func moveFiles(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
