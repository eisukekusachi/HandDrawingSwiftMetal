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
}
