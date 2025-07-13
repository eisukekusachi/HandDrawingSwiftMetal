//
//  CanvasState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// Manage the state of the canvas
final class CanvasState: ObservableObject {

    /// A name of the file to be saved
    @Published var projectName: String = Calendar.currentDate

    @Published var textureSize: CGSize = CanvasState.defaultTextureSize

    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

    @Published var drawingTool: DrawingToolType = .brush

    let brush = DrawingBrushToolState()

    let eraser = DrawingEraserToolState()

    /// Subject to publish updates for the canvas
    let canvasUpdateSubject = PassthroughSubject<Void, Never>()

    /// Subject to publish updates for the entire canvas, including all textures
    let fullCanvasUpdateSubject = PassthroughSubject<Void, Never>()

    private(set) var currentDrawingTool: DrawingToolProtocol!

    private static let defaultTextureSize: CGSize = .init(width: 768, height: 1024)

    init(_ configuration: CanvasConfiguration) {
        setData(configuration)
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
        currentDrawingTool.diameter
    }

    func layer(_ layerId: UUID) -> TextureLayerModel? {
        layers.first(where: { $0.id == layerId })
    }

    func setData(_ configuration: CanvasConfiguration) {
        /*
        projectName = configuration.projectName
        textureSize = configuration.textureSize ?? CanvasState.defaultTextureSize
        layers.removeAll()
        layers = configuration.layers
        selectedLayerId = layers.isEmpty ? nil : layers[configuration.layerIndex].id
        drawingToolState.setData(configuration)
*/
        self.projectName = configuration.projectName
        self.textureSize = configuration.textureSize ?? CanvasState.defaultTextureSize

        self.layers.removeAll()
        self.layers = configuration.layers
        self.selectedLayerId = layers.isEmpty ? nil : layers[configuration.layerIndex].id

        self.brush.color = configuration.brushColor
        self.brush.setDiameter(configuration.brushDiameter)

        self.eraser.alpha = configuration.eraserAlpha
        self.eraser.setDiameter(configuration.eraserDiameter)

        self.currentDrawingTool = self.brush

        self.drawingTool = configuration.drawingTool
    }
}

extension CanvasState {

    func addLayer(newTextureLayer textureLayer: TextureLayerModel, at index: Int) {
        self.layers.insert(textureLayer, at: index)
        self.selectedLayerId = textureLayer.id
    }

    func removeLayer(textureLayer: TextureLayerModel, newSelectedLayerId: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == textureLayer.id }) else { return }
        self.layers.remove(at: index)
        self.selectedLayerId = newSelectedLayerId
    }

    func moveLayer(
        indices: MoveLayerIndices,
        selectedLayerId: UUID
    ) {
        self.layers.move(fromOffsets: indices.sourceIndexSet, toOffset: indices.destinationIndex)
        self.selectedLayerId = selectedLayerId
    }

    func updateLayer(newTextureLayer: TextureLayerModel) {
        guard let index = layers.firstIndex(where: { $0.id == newTextureLayer.id }) else { return }
        self.layers[index] = newTextureLayer
        self.selectedLayerId = newTextureLayer.id
    }
}
