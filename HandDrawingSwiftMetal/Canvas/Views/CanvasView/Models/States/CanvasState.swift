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

    let drawingToolState = DrawingToolState(
        configuration: CanvasConfiguration()
    )

    /// If `layers` is empty, a new layer is created and added to `layers`
    /// when `initializeStorage(from:)` is called in `TextureRepository`
    @Published var layers: [TextureLayerModel] = []

    @Published var selectedLayerId: UUID?

    @Published var backgroundColor: UIColor = .white

    /// Subject to publish updates for the canvas
    let canvasUpdateSubject = PassthroughSubject<Void, Never>()

    /// Subject to publish updates for the entire canvas, including all textures
    let fullCanvasUpdateSubject = PassthroughSubject<Void, Never>()

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
        drawingToolState.currentDrawingTool.diameter
    }

    func getLayer(_ selectedLayerId: UUID) -> TextureLayerModel? {
        layers.first(where: { $0.id == selectedLayerId })
    }

    func setData(_ configuration: CanvasConfiguration) {
        projectName = configuration.projectName
        textureSize = configuration.textureSize ?? CanvasState.defaultTextureSize
        layers.removeAll()
        layers = configuration.layers
        selectedLayerId = layers.isEmpty ? nil : layers[configuration.layerIndex].id
        drawingToolState.setData(configuration)
    }

}
