//
//  CanvasDrawingState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit

final class CanvasDrawingState: ObservableObject {

    @Published var drawingToolType: DrawingToolType = .brush {
        didSet {
            switch drawingToolType {
            case .brush: currentDrawingTool = brush
            case .eraser: currentDrawingTool = eraser
            }
        }
    }

    private(set) var brush = DrawingBrushTool()

    private(set) var eraser = DrawingEraserTool()

    private(set) var currentDrawingTool: DrawingToolProtocol!

}

extension CanvasDrawingState {

    convenience init(model: CanvasModel) {
        self.init()

        brush.setDiameter(model.brushDiameter)
        eraser.setDiameter(model.eraserDiameter)
        drawingToolType = .init(rawValue: model.drawingTool)
    }

}
