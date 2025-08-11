//
//  HandDrawingContentViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import CanvasView
import UIKit

final class HandDrawingContentViewModel: ObservableObject {

    private(set) var brushColors: [UIColor] = []
    private(set) var eraserAlphas: [Int] = []

    var selectedBrushColorIndex: Int = 0
    var selectedEraserAlphaIndex: Int = 0

    var drawingTool: DrawingToolType = .brush

    var brushColor: UIColor {
        guard selectedBrushColorIndex < brushColors.count else { return .black }
        return brushColors[selectedBrushColorIndex]
    }

    var eraserAlpha: Int {
        guard selectedEraserAlphaIndex < eraserAlphas.count else { return 255 }
        return eraserAlphas[selectedEraserAlphaIndex]
    }

    init(
        brushColors: [UIColor] = [],
        eraserAlphas: [Int] = [],
        selectedBrushColorIndex: Int = 0,
        selectedEraserAlphaIndex: Int = 0
    ) {
        self.brushColors = brushColors
        self.eraserAlphas = eraserAlphas
        self.selectedBrushColorIndex = selectedBrushColorIndex
        self.selectedEraserAlphaIndex = selectedEraserAlphaIndex

        if brushColors.isEmpty {
            self.brushColors = [
                .black
            ]
        }
        if eraserAlphas.isEmpty {
            self.eraserAlphas = [
                255
            ]
        }
    }

    func changeDrawingTool() {
        if drawingTool == .brush {
            drawingTool = .eraser
        } else {
            drawingTool = .brush
        }
    }
}
