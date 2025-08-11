//
//  HandDrawingContentViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import CanvasView
import UIKit

final class HandDrawingContentViewModel: ObservableObject {

    var drawingTool: DrawingToolType = .brush

    func changeDrawingTool() {
        if drawingTool == .brush {
            drawingTool = .eraser
        } else {
            drawingTool = .brush
        }
    }
}
