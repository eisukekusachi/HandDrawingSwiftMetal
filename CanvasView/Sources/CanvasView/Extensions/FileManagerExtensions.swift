//
//  FileManagerExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation

public extension FileManager {

    static func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func createNewDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(atPath: url.path)
        }

        try FileManager.createDirectory(url)
    }

    /// The URL of a canvas file stored in the Documents directory
    static func documentsFileURL(projectName: String, suffix: String) -> URL {
        URL.documents.appendingPathComponent(projectName + "." + suffix)
    }

    static func contentsOfDirectory(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }

    static func containsAll(fileNames: [String], in fileURLs: [URL]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        return Set(fileNames).isSubset(of: Set(fileURLs.map { $0.lastPathComponent }))
    }
}
