//
//  URLExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension URL {

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

    var baseName: String {
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

extension URL {

    static func normalizedName(
        oldName: String,
        newName: String
    ) -> String {
        let sanitizedName = URL.sanitizedName(
            URL.trimmedName(oldName: oldName, newName: newName)
        )
        return URL.trimmedName(
            oldName: oldName,
            newName: sanitizedName
        )
    }

    static func trimmedName(
        oldName: String,
        newName: String
    ) -> String {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? oldName : trimmedName
    }

    static func sanitizedName(_ raw: String) -> String {
        var string = raw
        for char in ["/", "\\", ":", "?", "%", "*", "|", "\"", "<", ">"] {
            string = string.replacingOccurrences(of: char, with: "")
        }
        return string
    }

    static func projectName(name: String, fileSuffix: String = "") -> String {
        if fileSuffix.isEmpty {
            return name
        }
        return name + "." + fileSuffix
    }

    /// Convenience overload using the real filesystem (`FileManager.default.fileExists`).
    static func uniqueProjectURLInDocuments(
        fileName: String,
        fileSuffix: String
    ) throws -> URL {
        try uniqueProjectURLInDocuments(
            fileName: fileName,
            fileSuffix: fileSuffix,
            exists: { FileManager.default.fileExists(atPath: $0.path) }
        )
    }
}

extension URL {
    /// Returns a unique file URL in Documents by appending `_2`, `_3`, ... when needed.
    /// This function is pure except for the injected `exists` predicate.
    static func uniqueProjectURLInDocuments(
        fileName: String,
        fileSuffix: String,
        exists: (URL) -> Bool
    ) throws -> URL {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFileName.isEmpty else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Please enter a file name")
            )
        }

        let newFileName = URL.sanitizedName(trimmedFileName)
        guard !newFileName.isEmpty else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Invalid Value")
            )
        }

        return uniqueURL(
            baseName: newFileName,
            fileSuffix: fileSuffix,
            excludeURL: nil,
            exists: exists
        )
    }

    static func uniqueURL(
        baseName: String,
        fileSuffix: String,
        excludeURL: URL? = nil
    ) -> URL {
        uniqueURL(
            baseName: baseName,
            fileSuffix: fileSuffix,
            excludeURL: excludeURL,
            exists: { FileManager.default.fileExists(atPath: $0.path) }
        )
    }

    static func uniqueURL(
        baseName: String,
        fileSuffix: String,
        excludeURL: URL? = nil,
        exists: (URL) -> Bool
    ) -> URL {
        var newFileURL = FileManager.zipFileURL(projectName: baseName, suffix: fileSuffix)
        var suffixIndex = 2

        while exists(newFileURL) && newFileURL != excludeURL {
            newFileURL = FileManager.zipFileURL(projectName: "\(baseName)_\(suffixIndex)", suffix: fileSuffix)
            suffixIndex += 1
        }

        return newFileURL
    }
}
