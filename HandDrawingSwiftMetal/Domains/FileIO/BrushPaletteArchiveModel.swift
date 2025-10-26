//
//  BrushPaletteArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct BrushPaletteArchiveModel: Codable, Sendable {
    let index: Int
    let hexColors: [String]

    init(index: Int, hexColors: [String]) {
        self.index = index
        self.hexColors = hexColors
    }
}

extension BrushPaletteArchiveModel {
    @MainActor
    init(_ palette: BrushPalette) {
        self.index = palette.index
        self.hexColors = palette.colors.map { $0.hex() }
    }
}

extension BrushPaletteArchiveModel: LocalFileConvertible {
    static var fileName: String { "brush_palette" }
}
