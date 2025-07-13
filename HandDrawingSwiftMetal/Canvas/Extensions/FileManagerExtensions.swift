//
//  FileManagerExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation

extension FileManager {

    static func createNewDirectory(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            } catch {
                throw error
            }
        }

        do {
            try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw error
        }
    }

    static func clearContents(of folder: URL) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.removeItem(at: file)
        }
    }

    static func contentsOfDirectory(_ url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }

    static func containsAll(fileNames: [String], in fileURLs: [URL]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        return Set(fileNames).isSubset(of: Set(fileURLs.map { $0.lastPathComponent }))
    }
}
