//
//  FileManagerWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/29.
//

import Foundation

/// A protocol that abstracts file system operations
protocol FileManagerWrapping: Sendable {
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
    func removeItem(at url: URL) throws
}

/// An implementation of `FileManagerWrapping` that delegates to `FileManager.default`
struct FileManagerWrapper: FileManagerWrapping {
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
