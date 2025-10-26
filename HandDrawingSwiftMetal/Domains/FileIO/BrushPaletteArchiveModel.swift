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
}

extension BrushPaletteArchiveModel: LocalFileConvertible {

    public static var fileName: String { "brush_palette" }

    static func read(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url.appendingPathComponent(BrushPaletteArchiveModel.fileName))
        return try JSONDecoder().decode(Self.self, from: data)
    }

    @MainActor
    static func localFileItem(from palette: BrushPalette) -> LocalFileItem<BrushPaletteArchiveModel> {
        .init(
            fileName: BrushPaletteArchiveModel.fileName,
            item: .init(
                index: palette.index,
                hexColors: palette.colors.map { $0.hex() }
            )
        )
    }
}
