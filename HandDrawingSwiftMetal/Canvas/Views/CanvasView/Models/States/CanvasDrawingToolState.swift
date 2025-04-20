//
//  CanvasDrawingToolState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit

/// Manage the state of drawing tools
final class CanvasDrawingToolState: ObservableObject {

    @Published var drawingToolType: DrawingToolType = .brush {
        didSet {
            switch drawingToolType {
            case .brush: currentDrawingTool = brush
            case .eraser: currentDrawingTool = eraser
            }
        }
    }

    private(set) lazy var brush = DrawingBrushToolState()

    private(set) lazy var eraser = DrawingEraserToolState()

    private(set) var currentDrawingTool: DrawingToolProtocol!

    init(
        brushColor: UIColor,
        brushDiameter: Int,
        eraserAlpha: Int,
        eraserDiameter: Int,
        drawingToolType: DrawingToolType
    ) {
        self.brush.color = brushColor
        self.brush.setDiameter(brushDiameter)

        self.eraser.alpha = eraserAlpha
        self.eraser.setDiameter(eraserDiameter)

        self.drawingToolType = drawingToolType
    }

}

extension CanvasDrawingToolState {

    func setData(_ model: CanvasModel) {

        brush.setDiameter(model.brushDiameter)
        eraser.setDiameter(model.eraserDiameter)

        drawingToolType = model.drawingTool
    }

}
