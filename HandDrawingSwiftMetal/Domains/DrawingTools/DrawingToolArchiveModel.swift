//
//  DrawingToolArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/25.
//

import Foundation

struct DrawingToolArchiveModel: Codable, Sendable {
    let type: Int
    let brushDiameter: Int
    let eraserDiameter: Int
}

extension DrawingToolArchiveModel {
    @MainActor
    init(_ drawingTool: DrawingTool) {
        type = drawingTool.type.rawValue
        brushDiameter = drawingTool.brushDiameter
        eraserDiameter = drawingTool.eraserDiameter
    }
}

extension DrawingToolArchiveModel: LocalFileConvertible {
    static var fileName: String { "drawing_tool" }
}
