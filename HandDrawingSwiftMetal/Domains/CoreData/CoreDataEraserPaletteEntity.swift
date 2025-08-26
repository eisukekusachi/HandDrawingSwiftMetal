//
//  CoreDataEraserPaletteEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct CoreDataEraserPaletteEntity: Codable, Sendable {
    public let index: Int
    public let alphas: [Int]

    public static let fileName = "eraser_palette"
}

extension CoreDataEraserPaletteEntity: LocalFileConvertible {
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
extension CoreDataEraserPaletteEntity {
    static func namedItem(from palette: EraserPalette) -> LocalFileNamedItem<CoreDataEraserPaletteEntity> {
        .init(
            fileName: "\(Self.fileName)",
            item: .init(
                index: palette.currentIndex,
                alphas: palette.alphas
            )
        )
    }

    static func anyNamedItem(from palette: EraserPalette) -> AnyLocalFileNamedItem {
        AnyLocalFileNamedItem(Self.namedItem(from: palette))
    }
}

extension CoreDataEraserPaletteEntity: LocalFileLoadable {}
