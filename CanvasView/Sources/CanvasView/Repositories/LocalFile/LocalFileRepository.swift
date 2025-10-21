//
//  LocalFileRepository.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/07/31.
//

import Foundation

@MainActor
public protocol LocalFileRepository: Sendable {

    var workingDirectoryURL: URL { get }

    func createWorkingDirectory() throws

    func removeWorkingDirectory()

    /// Compresses the working directory contents into a ZIP file
    func zipWorkingDirectory(to zipFileURL: URL) throws

    /// Unzips a file into the working directory
    func unzipToWorkingDirectoryAsync(from zipFileURL: URL) async throws -> URL
}
