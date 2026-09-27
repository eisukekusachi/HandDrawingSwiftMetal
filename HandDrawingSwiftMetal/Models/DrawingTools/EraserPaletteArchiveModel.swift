//
//  EraserPaletteArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Core
import Foundation

struct EraserPaletteArchiveModel: Codable, Sendable {
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

extension EraserPaletteArchiveModel: LocalFileConvertible {
    static var fileName: String { "eraser_palette" }
}
