//
//  DrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/24.
//

import CanvasView
import UIKit

@MainActor
protocol DrawingToolProtocol {

    var id: UUID { get }

    var type: DrawingToolType { get }

    var brushDiameter: Int { get }

    var eraserDiameter: Int { get }

    func setDrawingTool(_ type: DrawingToolType)

    func setBrushDiameter(_ diameter: Int)

    func setEraserDiameter(_ diameter: Int)
}

public final class DrawingTool: DrawingToolProtocol, ObservableObject {

    private(set) var id: UUID

    @Published private(set) var type: DrawingToolType = .brush
    @Published private(set) var brushDiameter: Int = 8
    @Published private(set) var eraserDiameter: Int = 8

    private let initialType: DrawingToolType
    private let initialBrushDiameter: Int
    private let initialEraserDiameter: Int

    public init(
        id: UUID = UUID(),
        initialType: DrawingToolType = .brush,
        initialBrushDiameter: Int = 8,
        initialEraserDiameter: Int = 8
    ) {
        self.id = id

        self.initialType = initialType
        self.initialBrushDiameter = initialBrushDiameter
        self.initialEraserDiameter = initialEraserDiameter
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
