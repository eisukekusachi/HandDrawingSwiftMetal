//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import SwiftUI

/// Icons for `FileView`. Defaults are SF Symbols; pass any `Image` for custom assets.
public struct FileViewIcons {
    public var create: Image
    public var rename: Image
    public var delete: Image
    public var close: Image
    public var selectionBadge: Image
    public var unsavedPlaceholder: Image

    public init(
        create: Image = Image(systemName: "plus.circle"),
        rename: Image = Image(systemName: "pencil"),
        delete: Image = Image(systemName: "trash"),
        close: Image = Image(systemName: "xmark.circle.fill"),
        selectionBadge: Image = Image(systemName: "checkmark.circle.fill"),
        unsavedPlaceholder: Image = Image(systemName: "questionmark.circle.fill")
    ) {
        self.create = create
        self.rename = rename
        self.delete = delete
        self.close = close
        self.selectionBadge = selectionBadge
        self.unsavedPlaceholder = unsavedPlaceholder
    }
}
