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

    /// Stores the current texture size
    var currentTextureSize: CGSize?

    let drawingToolState = DrawingToolState(
        canvasModel: CanvasModel()
    )

    /// If `layers` is empty, a new layer is created and added to `layers`
    /// when `restoreLayers(from:model, drawableSize:)` is called in `TextureLayers`.
    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

    @Published var isInitialized = false

    init(_ model: CanvasModel) {
        projectName = model.projectName
        layers = model.layers
        selectedLayerId = layers.isEmpty ? nil : layers[model.layerIndex].id
        drawingToolState.setData(model)

        currentTextureSize = model.textureSize
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

    func setData(_ model: CanvasModel) {
        layers.removeAll()
        layers = model.layers
        selectedLayerId = layers[model.layerIndex].id

        projectName = model.projectName

        drawingToolState.setData(model)

        currentTextureSize = model.textureSize

        isInitialized = true
    }

}
