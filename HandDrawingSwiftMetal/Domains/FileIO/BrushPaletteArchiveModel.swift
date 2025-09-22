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

    public static let jsonFileName = "brush_palette"
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
            fileName: "\(Self.jsonFileName)",
            item: .init(
                index: palette.index,
                hexColors: palette.colors.map { $0.hex() }
            )
        )
    }

    static func anyNamedItem(from palette: BrushPalette) -> AnyLocalFileNamedItem {
        AnyLocalFileNamedItem(Self.namedItem(from: palette))
    }
}

extension BrushPaletteArchiveModel: LocalFileLoadable {}
