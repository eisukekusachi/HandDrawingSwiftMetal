//
//  URLExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

public extension URL {

    static var documents: URL {
        guard
            let url = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
            fatalError("Failed to resolve Documents directory URL")
        }
        return url
    }

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

    var fileName: String {
        self.deletingPathExtension().lastPathComponent
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
