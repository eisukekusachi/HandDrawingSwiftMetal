//
//  LocalFileRepository.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/07/31.
//

import Foundation

public protocol LocalFileRepository: Sendable {

    func createWorkingDirectory() throws

    func removeWorkingDirectory()

    /// Compresses the working directory contents into a ZIP file
    func zipWorkingDirectory(to zipFileURL: URL) throws

    /// Unzips a file into the working directory
    func unzipToWorkingDirectoryAsync(from zipFileURL: URL) async throws -> URL

    /// Saves a single file item to the working directory
    func saveToWorkingDirectory<T: LocalFileConvertible>(namedItem: LocalFileNamedItem<T>) async throws -> URL

    /// Saves multiple file items to the working directory
    func saveAllToWorkingDirectory<T: LocalFileConvertible & Sendable>(namedItems: [LocalFileNamedItem<T>]) async throws -> [URL]
}
