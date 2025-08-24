//
//  HandDrawingContentViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import CanvasView
import UIKit

@MainActor
final class HandDrawingContentViewModel: ObservableObject {

    private let drawingToolController: PersistenceController

    @Published var brushPalette: BrushPalette
    @Published var eraserPalette: EraserPalette

    var drawingTool: DrawingToolType = .brush

    public init() {
        drawingToolController = PersistenceController(modelName: "DrawingToolStorage")

        brushPalette = BrushPalette(
            initialColors: [
                .black.withAlphaComponent(0.8),
                .gray.withAlphaComponent(0.8),
                .red.withAlphaComponent(0.8),
                .blue.withAlphaComponent(0.8),
                .green.withAlphaComponent(0.8),
                .yellow.withAlphaComponent(0.8)
            ],
            storage: BrushPalette.CoreDataStorage(
                context: drawingToolController.context
            )
        )
        eraserPalette = EraserPalette(
            initialAlphas: [
                255,
                200,
                150,
                100,
                50
            ],
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
