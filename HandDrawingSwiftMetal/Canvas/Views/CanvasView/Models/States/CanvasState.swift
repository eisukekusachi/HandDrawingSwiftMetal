//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import UIKit

final class CanvasState: ObservableObject {
    
    let drawingState = CanvasDrawingState()

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

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

    var drawingToolDiameter: Int {
        drawingState.currentDrawingTool.diameter
    }

    func setData(_ model: CanvasModel) {
        layers.removeAll()
        layers = model.layers
        selectedLayerId = layers[model.layerIndex].id

        projectName = model.projectName

        drawingState.brush.setDiameter(model.brushDiameter)
        drawingState.eraser.setDiameter(model.eraserDiameter)
        drawingState.drawingToolType = .init(rawValue: model.drawingTool)
    }

}
