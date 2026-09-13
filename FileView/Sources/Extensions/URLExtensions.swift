//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Foundation

extension URL {

    public var baseName: String {
        deletingPathExtension().lastPathComponent
    }

    public static func normalizedName(
        fallbackName: String,
        newName: String
    ) -> String {
        let sanitizedName = URL.sanitizedName(
            URL.trimmedName(fallbackName: fallbackName, newName: newName)
        )
        return URL.trimmedName(
            fallbackName: fallbackName,
            newName: sanitizedName
        )
    }

    /// Trims `newName`. When the result is empty, returns `fallbackName` as-is
    /// (even if `fallbackName` is empty).
    public static func trimmedName(
        fallbackName: String,
        newName: String
    ) -> String {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallbackName : trimmedName
    }

    public static func sanitizedName(_ raw: String) -> String {
        var string = raw
        for char in ["/", "\\", ":", "?", "%", "*", "|", "\"", "<", ">"] {
            string = string.replacingOccurrences(of: char, with: "")
        }
        return string
    }

    public static func projectName(name: String, fileSuffix: String = "") -> String {
        if fileSuffix.isEmpty {
            return name
        }
        return name + "." + fileSuffix
    }

    public static func fileURL(
        in directory: URL,
        name: String,
        fileSuffix: String = ""
    ) -> URL {
        directory.appendingPathComponent(
            projectName(name: name, fileSuffix: fileSuffix)
        )
    }
}
