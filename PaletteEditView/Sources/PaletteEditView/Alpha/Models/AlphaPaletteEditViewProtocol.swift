//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Combine

/// A read-only source of the selected alpha for `AlphaPaletteEditView`.
@MainActor
public protocol AlphaPaletteEditViewProtocol: AnyObject {
    /// The alpha value of the selected item.
    var selectedAlpha: Int { get }
    /// The index of the selected item.
    var selectedIndex: Int { get }
    /// Whether the selected item can be removed. `false` when only one item remains.
    var canRemoveSelected: Bool { get }
}

public typealias AlphaPaletteSource = AlphaPaletteEditViewProtocol & ObservableObject
