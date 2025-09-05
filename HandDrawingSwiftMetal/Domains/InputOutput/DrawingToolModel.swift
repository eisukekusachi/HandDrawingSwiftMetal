//
//  DrawingToolModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import CanvasView
import Foundation

struct DrawingToolModel: Codable, Sendable {
    public let type: Int
    public let brushDiameter: Int
    public let eraserDiameter: Int

    public static let fileName = "drawing-tool"
}

extension DrawingToolModel: LocalFileConvertible {
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
extension DrawingToolModel {
    static func namedItem(from drawingTool: DrawingTool) -> LocalFileNamedItem<DrawingToolModel> {
        .init(
            fileName: "\(Self.fileName)",
            item: .init(
                type: drawingTool.type.rawValue,
                brushDiameter: drawingTool.brushDiameter,
                eraserDiameter: drawingTool.eraserDiameter
            )
        )
    }

    static func anyNamedItem(from drawingTool: DrawingTool) -> AnyLocalFileNamedItem {
        AnyLocalFileNamedItem(Self.namedItem(from: drawingTool))
    }
}

extension DrawingToolModel: LocalFileLoadable {}
