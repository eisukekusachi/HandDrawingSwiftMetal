//
//  DrawingToolState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit

/// Manage the state of drawing tools
final class DrawingToolState: ObservableObject {

    @Published var drawingTool: DrawingToolType = .brush {
        didSet {
            switch drawingTool {
            case .brush: currentDrawingTool = brush
            case .eraser: currentDrawingTool = eraser
            }
        }
    }

    private(set) lazy var brush = DrawingBrushToolState()

    private(set) lazy var eraser = DrawingEraserToolState()

    private(set) var currentDrawingTool: DrawingToolProtocol!

    convenience init(
        brushColor: UIColor,
        eraserAlpha: Int,
        canvasModel: CanvasModel
    ) {
        self.init()

        self.brush.color = brushColor
        self.brush.setDiameter(canvasModel.brushDiameter)

        self.eraser.alpha = eraserAlpha
        self.eraser.setDiameter(canvasModel.eraserDiameter)

        self.drawingTool = canvasModel.drawingTool
    }
    convenience init(
        brushColor: UIColor,
        brushDiameter: Int,
        eraserAlpha: Int,
        eraserDiameter: Int,
        drawingTool: DrawingToolType
    ) {
        self.init()

        self.brush.color = brushColor
        self.brush.setDiameter(brushDiameter)

        self.eraser.alpha = eraserAlpha
        self.eraser.setDiameter(eraserDiameter)

        self.drawingTool = drawingTool
    }

}

extension DrawingToolState {

    func setData(_ model: CanvasModel) {

        brush.setDiameter(model.brushDiameter)
        eraser.setDiameter(model.eraserDiameter)

        drawingTool = model.drawingTool
    }

}
