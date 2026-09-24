//
//  DrawingToolArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Core
import Foundation

struct DrawingToolArchiveModel: Codable, Sendable {
    let type: Int
    let brushDiameter: Int
    let eraserDiameter: Int

    init(type: Int, brushDiameter: Int, eraserDiameter: Int) {
        self.type = type
        self.brushDiameter = brushDiameter
        self.eraserDiameter = eraserDiameter
    }

    @MainActor
    init(_ drawingTool: DrawingTool) {
        self.init(
            type: drawingTool.type.rawValue,
            brushDiameter: drawingTool.brushDiameter,
            eraserDiameter: drawingTool.eraserDiameter
        )
    }
}

extension DrawingToolArchiveModel: LocalFileConvertible {
    static var fileName: String { "drawing_tool" }
}
