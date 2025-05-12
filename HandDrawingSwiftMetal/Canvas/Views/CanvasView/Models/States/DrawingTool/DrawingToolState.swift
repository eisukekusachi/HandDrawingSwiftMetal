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
        configuration: CanvasConfiguration
    ) {
        self.init()

        self.brush.color = configuration.brushColor
        self.brush.setDiameter(configuration.brushDiameter)

        self.eraser.alpha = configuration.eraserAlpha
        self.eraser.setDiameter(configuration.eraserDiameter)

        self.drawingTool = configuration.drawingTool
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

    func setData(_ configuration: CanvasConfiguration) {

        brush.setDiameter(configuration.brushDiameter)
        eraser.setDiameter(configuration.eraserDiameter)

        drawingTool = configuration.drawingTool
    }

}
