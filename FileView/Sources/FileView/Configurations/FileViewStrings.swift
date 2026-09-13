//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import Foundation

/// User-facing copy for `FileView`. Defaults come from the package String Catalog.
public struct FileViewStrings: Equatable, Sendable {
    public var renameTitle: String
    public var renamePrompt: String
    public var renameMessage: String
    public var ok: String
    public var cancel: String
    public var notSavedYet: String
    public var resetCanvasTitle: String
    public var deleteFileTitle: String
    public var resetCanvasMessage: String
    public var deleteFileMessage: String
    public var reset: String
    public var delete: String

    public init(
        renameTitle: String? = nil,
        renamePrompt: String? = nil,
        renameMessage: String? = nil,
        ok: String? = nil,
        cancel: String? = nil,
        notSavedYet: String? = nil,
        resetCanvasTitle: String? = nil,
        deleteFileTitle: String? = nil,
        resetCanvasMessage: String? = nil,
        deleteFileMessage: String? = nil,
        reset: String? = nil,
        delete: String? = nil
    ) {
        self.renameTitle = renameTitle
            ?? String(localized: "Rename", bundle: .module)
        self.renamePrompt = renamePrompt
            ?? String(localized: "Name", bundle: .module)
        self.renameMessage = renameMessage
            ?? String(localized: "Enter a new name", bundle: .module)
        self.ok = ok
            ?? String(localized: "OK", bundle: .module)
        self.cancel = cancel
            ?? String(localized: "Cancel", bundle: .module)
        self.notSavedYet = notSavedYet
            ?? String(localized: "Not saved yet", bundle: .module)
        self.resetCanvasTitle = resetCanvasTitle
            ?? String(localized: "Reset this canvas?", bundle: .module)
        self.deleteFileTitle = deleteFileTitle
            ?? String(localized: "Delete this file?", bundle: .module)
        self.resetCanvasMessage = resetCanvasMessage
            ?? String(
                localized: "The drawing will be cleared. The file will remain.",
                bundle: .module
            )
        self.deleteFileMessage = deleteFileMessage
            ?? String(
                localized: "This file will be removed from the device",
                bundle: .module
            )
        self.reset = reset
            ?? String(localized: "Reset", bundle: .module)
        self.delete = delete
            ?? String(localized: "Delete", bundle: .module)
    }
}
