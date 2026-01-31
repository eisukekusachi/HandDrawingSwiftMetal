//
//  DrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/24.
//

import UIKit

public final class DrawingTool: ObservableObject {

    private(set) var id: UUID

    @Published private(set) var type: DrawingToolType = .brush
    @Published private(set) var brushDiameter: Int = 8
    @Published private(set) var eraserDiameter: Int = 8

    public init(
        id: UUID = UUID(),
        type: DrawingToolType = .brush,
        brushDiameter: Int = 8,
        eraserDiameter: Int = 8
    ) {
        self.id = id
        self.type = type
        self.brushDiameter = brushDiameter
        self.eraserDiameter = eraserDiameter
    }
}

extension DrawingTool {

    func setId(_ id: UUID) {
        self.id = id
    }

    func setDrawingTool(_ type: DrawingToolType) {
        self.type = type
    }

    func setBrushDiameter(_ diameter: Int) {
        self.brushDiameter = diameter
    }

    func setEraserDiameter(_ diameter: Int) {
        self.eraserDiameter = diameter
    }
}
