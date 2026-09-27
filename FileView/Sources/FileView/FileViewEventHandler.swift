//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Foundation

public struct FileViewEventHandler {
    let onTapCreate: () -> Void
    let onTapRename: (Int, String) -> String?
    let onTapDelete: (Int) -> Void
    let onSelectItem: (URL) -> Void
    public init(
        onTapCreate: @escaping () -> Void,
        onTapRename: @escaping (Int, String) -> String?,
        onTapDelete: @escaping (Int) -> Void,
        onSelectItem: @escaping (URL) -> Void
    ) {
        self.onTapCreate = onTapCreate
        self.onTapRename = onTapRename
        self.onTapDelete = onTapDelete
        self.onSelectItem = onSelectItem
    }
}
