//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import UIKit

/// Manage the state of the canvas
final class CanvasState: ObservableObject {

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    let drawingToolState = DrawingToolState(
        configuration: CanvasConfiguration()
    )

    /// If `layers` is empty, a new layer is created and added to `layers`
    /// when `resolveCanvasView(from:, drawableSize:)` is called in `TextureRepository`
    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

    init(_ configuration: CanvasConfiguration) {
        projectName = configuration.projectName
        layers = configuration.layers
        selectedLayerId = layers.isEmpty ? nil : layers[configuration.layerIndex].id
        drawingToolState.setData(configuration)
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

    func getLayer(_ selectedLayerId: UUID) -> TextureLayerModel? {
        layers.first(where: { $0.id == selectedLayerId })
    }

    func setData(_ configuration: CanvasConfiguration) {
        layers.removeAll()
        layers = configuration.layers
        selectedLayerId = layers[configuration.layerIndex].id

        projectName = configuration.projectName

        drawingToolState.setData(configuration)
    }

}
