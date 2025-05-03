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

    static func moveFile(source: URL, destination: URL) throws {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            throw FileOutputError.filedToMove
        }
    }

    static func clearContents(of folder: URL) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.removeItem(at: file)
        }
    }

}
