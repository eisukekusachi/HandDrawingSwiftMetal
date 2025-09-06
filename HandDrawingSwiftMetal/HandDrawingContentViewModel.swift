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

    @Published var drawingTool: DrawingTool
    @Published var eraserPalette: EraserPalette

    @Published var brushPaletteStorage: CoreDataBrushPaletteStorage

    public init() {
        drawingToolController = PersistenceController(modelName: "DrawingToolStorage")

        drawingTool = DrawingTool(
            storage: DrawingTool.CoreDataStorage(
                context: drawingToolController.context
            )
        )

        brushPaletteStorage = CoreDataBrushPaletteStorage(
            palette: BrushPalette(
                colors: [
                    .black.withAlphaComponent(0.8),
                    .gray.withAlphaComponent(0.8),
                    .red.withAlphaComponent(0.8),
                    .blue.withAlphaComponent(0.8),
                    .green.withAlphaComponent(0.8),
                    .yellow.withAlphaComponent(0.8),
                    .purple.withAlphaComponent(0.8)
                ]
            ),
            context: drawingToolController.context
        )

        eraserPalette = EraserPalette(
            initialAlphas: [
                255,
                225,
                200,
                175,
                150,
                125,
                100,
                50
            ],
            storage: EraserPalette.CoreDataStorage(
                context: drawingToolController.context
            )
        )
    }

    func changeDrawingTool() {
        drawingTool.setDrawingTool(drawingTool.type == .brush ? .eraser: .brush)
    }
}
