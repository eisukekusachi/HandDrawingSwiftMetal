//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import UIKit

/// Manage the state of the canvas
final class CanvasState: ObservableObject {

    let drawingToolState = CanvasDrawingState(
        brushColor: UIColor(.black).withAlphaComponent(0.75),
        brushDiameter: 8,
        eraserAlpha: 155,
        eraserDiameter: 44,
        drawingToolType: .brush
    )

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    /// If `layers` is empty, a new layer is created and added to `layers`
    /// when `restoreLayers(from:model, drawableSize:)` is called in `TextureLayers`.
    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

    init(_ model: CanvasModel) {
        drawingToolState.setData(model)
    }

}

extension CanvasState {

    var selectedLayer: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layers.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    var drawingToolDiameter: Int? {
        drawingToolState.currentDrawingTool.diameter
    }

    func setData(_ model: CanvasModel) {
        layers.removeAll()
        layers = model.layers
        selectedLayerId = layers[model.layerIndex].id

        projectName = model.projectName

        drawingToolState.setData(model)
    }

    func setData(_ layer: TextureLayerModel) {
        layers.removeAll()
        layers.append(layer)
        selectedLayerId = layers[0].id

        projectName = Calendar.currentDate

        drawingToolState.setData(CanvasModel())
    }

}
