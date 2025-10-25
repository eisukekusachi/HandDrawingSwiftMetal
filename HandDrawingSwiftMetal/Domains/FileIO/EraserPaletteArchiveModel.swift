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

extension EraserPaletteArchiveModel: LocalFileConvertible {
    static var fileName: String { "eraser_palette" }

    static func read(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url.appendingPathComponent(EraserPaletteArchiveModel.fileName))
        return try JSONDecoder().decode(Self.self, from: data)
    }

    @MainActor
    static func savableFile(from palette: EraserPalette) -> SavableFile<EraserPaletteArchiveModel> {
        .init(
            fileName: EraserPaletteArchiveModel.fileName,
            item: .init(
                index: palette.index,
                alphas: palette.alphas
            )
        )
    }
}
