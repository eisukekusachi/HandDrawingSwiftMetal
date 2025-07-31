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
    let workingDirectoryURL: URL

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

    /// Saves a single file item to the working directory
    func saveToWorkingDirectory<T: LocalFileConvertible>(
        namedItem: LocalFileNamedItem<T>
    ) async throws -> URL {
        let fileURL = workingDirectoryURL.appendingPathComponent(namedItem.name)
        try namedItem.item.write(to: fileURL)
        return fileURL
    }

    /// Saves multiple file items to the working directory
    func saveAllToWorkingDirectory<T: LocalFileConvertible & Sendable>(
        namedItems: [LocalFileNamedItem<T>]
    ) async throws -> [URL] {
        try await withThrowingTaskGroup(of: URL.self) { group in
            for namedItem in namedItems {
                let item = namedItem
                group.addTask {
                    try await self.saveToWorkingDirectory(namedItem: item)
                }
            }

            var urls: [URL] = []
            for try await url in group {
                urls.append(url)
            }
            return urls
        }
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

enum DocumentsDirectoryRepositoryError: Error {
    case error(Error)
    case operationError(String)
    case invalidValue(String)
}
