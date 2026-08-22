//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import UIKit

/// A source of palette data for `ColorPaletteView`.
public protocol ColorPaletteDisplayProtocol: AnyObject {
    /// The color items in the palette.
    var items: [ColorPaletteItem] { get }
    /// The index of the selected item in `items`.
    var selectedIndex: Int { get }

    /// Selects the item at `index`.
    @discardableResult
    func select(_ index: Int) -> Bool
}
