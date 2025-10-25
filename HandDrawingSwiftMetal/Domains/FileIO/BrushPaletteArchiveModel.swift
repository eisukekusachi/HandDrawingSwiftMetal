//
//  BrushPaletteArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct BrushPaletteArchiveModel: Codable, Sendable {
    public let index: Int
    public let hexColors: [String]

    public static let fileName = "brush_palette"
}

extension BrushPaletteArchiveModel: LocalFileConvertible {
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
extension BrushPaletteArchiveModel {
    static func namedItem(from palette: BrushPalette) -> LocalFileNamedItem<BrushPaletteArchiveModel> {
        .init(
            fileName: "\(Self.fileName)",
            item: .init(
                index: palette.index,
                hexColors: palette.colors.map { $0.hex() }
            )
        )
    }
}

extension BrushPaletteArchiveModel: LocalFileLoadable {}
