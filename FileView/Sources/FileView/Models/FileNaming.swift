//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import Foundation

/// Domain rules for saved-file names and supported extensions.
public struct FileNaming: Sendable, Equatable {
    /// Path extension without `.`.
    public let fileSuffix: String

    public init(fileSuffix: String) {
        self.fileSuffix = String(fileSuffix.drop(while: { $0 == "." }))
    }

    /// Whether `url` is a file whose extension matches `fileSuffix`.
    public func isSupportedFileURL(_ url: URL) -> Bool {
        !url.hasDirectoryPath && url.pathExtension == fileSuffix
    }

    /// Returns a sanitized title unused by `existingTitles`.
    /// Appends `_2`, `_3`, … when the base name is already taken.
    public func uniqueTitle(
        from baseName: String,
        existingTitles: some Sequence<String>
    ) -> String {
        let titles = Set(existingTitles)
        let sanitized = URL.sanitizedName(baseName)
        var newName = sanitized
        var suffix = 2

        while titles.contains(newName) {
            newName = "\(sanitized)_\(suffix)"
            suffix += 1
        }

        return newName
    }
}
