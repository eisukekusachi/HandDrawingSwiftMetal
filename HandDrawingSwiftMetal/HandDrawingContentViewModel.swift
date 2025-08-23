//
//  HandDrawingContentViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import CanvasView
import UIKit

final class HandDrawingContentViewModel: ObservableObject {

    private let drawingToolController: PersistenceController

    @Published var brushPalette: BrushPalette
    @Published var eraserPalette: EraserPalette

    var drawingTool: DrawingToolType = .brush

    public init() {
        drawingToolController = PersistenceController(modelName: "Drawingtool")

        brushPalette = BrushPalette(
            storage: BrushPalette.CoreDataStorage(
                context: drawingToolController.context
            )
        )
        eraserPalette = EraserPalette(
            storage: EraserPalette.CoreDataStorage(
                context: drawingToolController.context
            )
        )
    }

    func changeDrawingTool() {
        if drawingTool == .brush {
            drawingTool = .eraser
        } else {
            drawingTool = .brush
        }
    }
}
