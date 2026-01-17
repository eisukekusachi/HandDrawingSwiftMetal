//
//  URLExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

public extension URL {

    static var documents: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
    }

    /// A URL to store persistent and temporary data
    static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    var fileName: String {
        self.lastPathComponent.components(separatedBy: ".").first ?? self.lastPathComponent
    }

    func allFileURLs(suffix: String = "") -> [URL] {
        if FileManager.default.fileExists(atPath: self.path) {
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: self,
                    includingPropertiesForKeys: nil
                )
                return urls.filter {
                    suffix.isEmpty || $0.lastPathComponent.hasSuffix(suffix)
                }
            } catch {
                Logger.error(error)
            }
        }
        return []
    }
}
