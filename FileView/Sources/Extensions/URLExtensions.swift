//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Core
import Foundation

extension URL {

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

    public static func fileURL(
        in directory: URL,
        name: String,
        fileSuffix: String = ""
    ) -> URL {
        directory.appendingPathComponent(
            URL.projectName(name: name, fileSuffix: fileSuffix)
        )
    }
}
