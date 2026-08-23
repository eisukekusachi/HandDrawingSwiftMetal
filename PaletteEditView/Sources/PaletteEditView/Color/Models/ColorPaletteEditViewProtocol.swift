//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Combine
import UIKit

/// A read-only source of the selected color for `ColorPaletteEditView`.
@MainActor
public protocol ColorPaletteEditViewProtocol: AnyObject {
    /// The color of the selected item.
    var selectedColor: UIColor { get }
    /// The index of the selected item.
    var selectedIndex: Int { get }
    /// Whether the selected item can be removed. `false` when only one item remains.
    var canRemoveSelected: Bool { get }
}

public typealias ColorPaletteSource = ColorPaletteEditViewProtocol & ObservableObject
