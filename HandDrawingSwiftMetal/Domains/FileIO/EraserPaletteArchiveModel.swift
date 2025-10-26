//
//  EraserPaletteArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct EraserPaletteArchiveModel: Codable, Sendable {
    public let index: Int
    public let alphas: [Int]
}

extension EraserPaletteArchiveModel {
    @MainActor
    init(_ palette: EraserPalette) {
        self.index = palette.index
        self.alphas = palette.alphas
    }
}

extension EraserPaletteArchiveModel: LocalFileConvertible {
    static var fileName: String { "eraser_palette" }
}
