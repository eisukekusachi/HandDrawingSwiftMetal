//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

/// Snapshot of `EraserPalette` used when saving and restoring.
struct EraserPaletteSnapshot: Codable, Sendable {
    public let index: Int
    public let alphas: [Int]

    init(index: Int, alphas: [Int]) {
        self.index = index
        self.alphas = alphas
    }

    @MainActor
    init(_ palette: EraserPalette) {
        self.init(
            index: palette.selectedIndex,
            alphas: palette.items.map(\.alpha)
        )
    }
}

extension EraserPaletteSnapshot: LocalFileConvertible {
    static var fileName: String { "eraser_palette" }
}
