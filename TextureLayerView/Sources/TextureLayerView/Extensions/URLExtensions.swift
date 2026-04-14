//
//  URLExtensions.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/28.
//

import Foundation

extension URL {

    /// A URL to store persistent and temporary data
    static var applicationSupport: URL {
        guard let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Failed to resolve Application Support directory URL")
        }
        return url
    }

    static var documents: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
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
