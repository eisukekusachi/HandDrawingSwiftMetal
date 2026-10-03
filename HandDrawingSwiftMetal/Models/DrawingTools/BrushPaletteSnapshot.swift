//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
import Foundation

/// Snapshot of `BrushPalette` used when saving and restoring.
/// Colors are stored as hex strings.
struct BrushPaletteSnapshot: Codable, Sendable {
    let index: Int
    let hexColors: [String]

    init(index: Int, hexColors: [String]) {
        self.index = index
        self.hexColors = hexColors
    }

    @MainActor
    init(_ palette: BrushPalette) {
        self.index = palette.selectedIndex
        self.hexColors = palette.items.map { $0.color.hex() }
    }
}

extension BrushPaletteSnapshot: LocalFileConvertible {
    static var fileName: String { "brush_palette" }
}
