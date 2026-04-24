//
//  FileManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/24.
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

    /// URL of the project file in Documents (suffix is optional).
    static func zipFileURL(projectName: String, suffix: String) -> URL {
        guard !suffix.isEmpty else {
            return URL.documents.appendingPathComponent(projectName)
        }
        return URL.documents.appendingPathComponent(projectName + "." + suffix)
    }

    static func contentsOfDirectory(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }

    /// Checks whether all specified file names are present in the given list of URLs
    static func containsAllFileNames(fileNames: [String], in fileURLs: [URL]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        return Set(fileNames).isSubset(of: Set(fileURLs.map { $0.lastPathComponent }))
    }
}
