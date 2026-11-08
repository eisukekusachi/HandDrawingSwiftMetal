//
//  Created by Eisuke Kusachi
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

    var baseName: String {
        deletingPathExtension().lastPathComponent
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
            return []
        }
    }
}

public extension URL {

    static func sanitizedName(_ raw: String) -> String {
        var string = raw
        for char in ["/", "\\", ":", "?", "%", "*", "|", "\"", "<", ">"] {
            string = string.replacingOccurrences(of: char, with: "")
        }
        return string
    }

    /// File name: `name` and `fileSuffix` combined.
    static func fileName(name: String, fileSuffix: String = "") -> String {
        let suffix = sanitizedSuffix(fileSuffix)
        if suffix.isEmpty {
            return name
        }
        return name + "." + suffix
    }

    /// Drops `.` and whitespace throughout `fileSuffix`, then removes other path-invalid characters.
    static func sanitizedSuffix(_ raw: String) -> String {
        let trimmed = raw.filter { !$0.isWhitespace && $0 != "." }
        return sanitizedName(trimmed)
    }

    /// Picks an unused file URL under `directory`, appending `_2`, `_3`, … to the base name when taken.
    static func uniqueFileURL(
        name: String,
        in directory: URL,
        fileSuffix: String,
        fileExists: (URL) -> Bool,
        excludeURL: URL? = nil
    ) throws -> URL {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Please enter a file name", bundle: .module)
            )
        }

        let baseName = sanitizedName(trimmedName)
        guard !baseName.isEmpty else {
            throw NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid Value", bundle: .module)
            )
        }

        var candidateURL = directory.appendingPathComponent(
            fileName(name: baseName, fileSuffix: fileSuffix)
        )
        var suffixIndex = 2
        while fileExists(candidateURL),
              excludeURL.map({ $0.path.lowercased() != candidateURL.path.lowercased() }) ?? true
        {
            candidateURL = directory.appendingPathComponent(
                fileName(name: "\(baseName)_\(suffixIndex)", fileSuffix: fileSuffix)
            )
            suffixIndex += 1
        }
        return candidateURL
    }
}
