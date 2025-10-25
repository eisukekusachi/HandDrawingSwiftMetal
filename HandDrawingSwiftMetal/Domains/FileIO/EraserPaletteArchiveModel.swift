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

    public static let fileName = "eraser_palette"
}

extension EraserPaletteArchiveModel: LocalFileConvertible {
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
extension EraserPaletteArchiveModel {
    static func namedItem(from palette: EraserPalette) -> LocalFileNamedItem<EraserPaletteArchiveModel> {
        .init(
            fileName: "\(Self.fileName)",
            item: .init(
                index: palette.index,
                alphas: palette.alphas
            )
        )
    }
}

extension EraserPaletteArchiveModel: LocalFileLoadable {}
