//
//  LineParameters.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/04.
//

import UIKit

struct LineParameters {
    /// Diameter size including blur
    let dotSize: BlurredDotSize
    /// Alpha of a line
    let alpha: Int
    /// Color of a brush
    let brushColor: UIColor?

    init(_ drawingTool: DrawingToolModel) {
        if drawingTool.drawingTool == .eraser {
            self.dotSize = BlurredDotSize.init(diameter: Float(drawingTool.eraserDiameter))
            self.alpha = drawingTool.eraserAlpha
            self.brushColor = nil

        } else {
            self.dotSize = BlurredDotSize.init(diameter: Float(drawingTool.brushDiameter))
            self.alpha = drawingTool.brushColor.alpha
            self.brushColor = drawingTool.brushColor
        }
    }

}
