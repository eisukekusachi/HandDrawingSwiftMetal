//
//  DrawingToolArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct DrawingToolArchiveModel: Codable, Sendable {
    public let type: Int
    public let brushDiameter: Int
    public let eraserDiameter: Int
}

extension DrawingToolArchiveModel: LocalFileConvertible {
    static var fileName: String { "drawing_tool" }

    static func read(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url.appendingPathComponent(DrawingToolArchiveModel.fileName))
        return try JSONDecoder().decode(Self.self, from: data)
    }

    @MainActor
    static func localFileItem(from drawingTool: DrawingTool) -> LocalFileItem<DrawingToolArchiveModel> {
        .init(
            fileName: DrawingToolArchiveModel.fileName,
            item: .init(
                type: drawingTool.type.rawValue,
                brushDiameter: drawingTool.brushDiameter,
                eraserDiameter: drawingTool.eraserDiameter
            )
        )
    }
}
