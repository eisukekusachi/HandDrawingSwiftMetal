//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import Foundation

/// A source of palette data for `AlphaPaletteView`.
public protocol AlphaPaletteDisplayProtocol: AnyObject {
    /// The alpha items in the palette.
    var items: [AlphaPaletteItem] { get }
    /// The index of the selected item in `items`.
    var selectedIndex: Int { get }

    /// Selects the item at `index`.
    /// Does nothing if `index` is out of bounds.
    func select(_ index: Int)
}
