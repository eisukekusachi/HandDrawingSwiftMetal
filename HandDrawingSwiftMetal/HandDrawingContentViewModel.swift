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

    @Published var drawingToolStorage: CoreDataDrawingToolStorage
    @Published var brushPaletteStorage: CoreDataBrushPaletteStorage
    @Published var eraserPaletteStorage: CoreDataEraserPaletteStorage

    public init() {
        drawingToolController = PersistenceController(xcdatamodeldName: "DrawingToolStorage", location: .mainApp)

        drawingToolStorage = CoreDataDrawingToolStorage(
            drawingTool: DrawingTool(),
            context: drawingToolController.viewContext
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
            context: drawingToolController.viewContext
        )

        eraserPaletteStorage = CoreDataEraserPaletteStorage(
            palette: EraserPalette(
                alphas: [
                    255,
                    225,
                    200,
                    175,
                    150,
                    125,
                    100,
                    50
                ],
                index: 0
            ),
            context: drawingToolController.viewContext
        )

        Task {
            if let drawingToolEntity = try drawingToolStorage.fetch() {
                drawingToolStorage.update(drawingToolEntity)
            }
            if let brushEntity = try brushPaletteStorage.fetch() {
                brushPaletteStorage.update(brushEntity)
            }
            if let eraserEntity = try eraserPaletteStorage.fetch() {
                eraserPaletteStorage.update(eraserEntity)
            }
        }
    }

    func toggleDrawingTool() {
        drawingToolStorage.setDrawingTool(
            drawingToolStorage.type == .brush ? .eraser: .brush
        )
    }
}
