//
//  LocalFileRepositoryProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/31.
//

import Foundation

protocol LocalFileRepositoryProtocol: Sendable {

    var workingDirectoryURL: URL { get }

    func createWorkingDirectory() throws

    func removeWorkingDirectory() throws

    /// Compresses all items in the working directory into a ZIP file
    func zipWorkingDirectory(
        to zipFileURL: URL
    ) throws

    /// Extracts the ZIP file into the working directory
    func unzipToWorkingDirectory(
        from zipFileURL: URL
    ) async throws
}
