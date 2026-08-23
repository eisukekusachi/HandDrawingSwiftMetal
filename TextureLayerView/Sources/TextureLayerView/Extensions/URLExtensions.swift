//
//  URLExtensions.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/28.
//

import Foundation

extension URL {
    static var documents: URL {
        resolvedDirectoryURL(.documentDirectory, name: "Documents")
    }

    /// A URL to store persistent and temporary data
    static var applicationSupport: URL {
        resolvedDirectoryURL(.applicationSupportDirectory, name: "Application Support")
    }

    func allFileURLs(suffix: String = "") -> [URL] {
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
            return []
        }
    }
}

private extension URL {
    static func resolvedDirectoryURL(
        _ directory: FileManager.SearchPathDirectory,
        name: String
    ) -> URL {
        guard let url = FileManager.default.urls(
            for: directory,
            in: .userDomainMask
        ).first else {
            let message = "Failed to resolve \(name) directory URL"
            Logger.error(message)
            fatalError(message)
        }
        return url
    }
}
