//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import SwiftUI
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

@MainActor
class TextureLayersState: ObservableObject, TextureLayersProtocol, TextureLayersCompositingProtocol {

    /// Selected layer for undo and persistence.
    var selectedLayerModel: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layerModels.first(where: { $0.id == selectedLayerId })
    }

    var selectedLayerIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layerModels.firstIndex(where: { $0.id == selectedLayerId })
    }

    /// Selected layer for the list and canvas compositing.
    var selectedLayer: TextureLayerItem? {
        guard let selectedLayerId else { return nil }
        return layers.first { $0.id == selectedLayerId }
    }

    /// Snapshot of the current layers for persistence
    var snapshot: TextureLayersSnapshot {
        .init(
            layers: layerModels,
            layerIndex: selectedLayerIndex ?? 0,
            textureSize: textureSize
        )
    }

    /// Presentation models for `TextureLayerView`.
    var layers: [TextureLayerItem] {
        layerModels.map { model in
                .init(model: model, thumbnail: thumbnails[model.id])
        }
    }

    @Published private(set) var layerModels: [TextureLayerModel] = []

    @Published private var thumbnails: [LayerId: UIImage] = [:]

    @Published private(set) var selectedLayerId: LayerId?

    @Published private(set) var textureSize: CGSize = .init(width: 768, height: 1024)

    private let repository: MTLTextureDataRepositoryProtocol?

    private var device: MTLDevice?

    private var commandQueue: MTLCommandQueue?

    private weak var canvasView: (any TextureLayerCanvasUpdating)?

    init(
        repository: MTLTextureDataRepositoryProtocol? = nil
    ) {
        self.repository = repository
    }

    /// The canvas is created from this object, so it is set up once the canvas exists.
    func setup(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        canvasView: any TextureLayerCanvasUpdating
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.canvasView = canvasView
    }

    func layer(_ id: LayerId) -> TextureLayerModel? {
        layerModels.first(where: { $0.id == id })
    }

    /// Restores the layer list from a saved snapshot.
    func setLayers(
        _ textureLayers: TextureLayersSnapshot
    ) throws {
        try setLayers(
            textureLayers.layers,
            textureSize: textureLayers.textureSize,
            selectedIndex: textureLayers.layerIndex
        )
    }

    func setLayers(
        _ layers: [TextureLayerModel],
        textureSize: CGSize,
        selectedIndex: Int = 0
    ) throws {
        guard !layers.isEmpty else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }

        layerModels = layers
        thumbnails = [:]
        let index = max(0, min(selectedIndex, layers.count - 1))
        selectedLayerId = layers[index].id
        self.textureSize = textureSize
    }

    func addLayer() async throws {
        guard let canvasView else { return }
        try canvasView.throwIfUnsavedDrawing()
        guard
            let repository,
            let device,
            let commandQueue
        else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }
        guard let anchorId = selectedLayerId else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }

        guard let texture = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            minimumLength: textureMinimumLength,
            with: device
        ) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }
        let id = LayerId()
        let data = try await texture.data(
            device: device,
            commandQueue: commandQueue
        )
        try await repository.addTextureData(data: data, id: id)
        guard let anchorIndex = layerModels.firstIndex(where: { $0.id == anchorId }) else {
            try repository.removeTexture(id)
            return
        }
        insertLayer(
            layer: .init(
                id: id,
                title: TimeStampFormatter.currentDate,
                alpha: 255,
                isVisible: true
            ),
            thumbnail: texture.makeThumbnail(),
            at: AddLayerIndex.insertIndex(selectedIndex: anchorIndex)
        )
        try await canvasView.updateFullCanvas()
    }

    func removeLayer(id: LayerId) async throws -> Bool {
        guard let canvasView else { return false }
        try canvasView.throwIfUnsavedDrawing()
        guard
            let repository,
            layerModels.count > 1,
            let index = layerModels.firstIndex(where: { $0.id == id }),
            try repository.removeTexture(id)
        else { return false }

        let removed = removeLayer(layerIndexToDelete: index)
        if removed {
            try await canvasView.updateFullCanvas()
        }
        return removed
    }

    func renameLayer(id: LayerId, title: String) throws {
        update(id, title: title)
    }

    func moveLayers(from source: IndexSet, to destination: Int) async throws {
        guard let canvasView else { return }
        try canvasView.throwIfUnsavedDrawing()
        moveLayer(
            indices: .init(
                sourceIndexSet: source,
                destinationIndex: destination
            )
        )
        try await canvasView.updateFullCanvas()
    }

    func selectLayer(id: LayerId) async throws {
        guard let canvasView else { return }
        try canvasView.throwIfUnsavedDrawing()
        selectLayer(id)
        try await canvasView.updateFullCanvas()
    }

    func setVisibility(id: LayerId, isVisible: Bool) async throws {
        guard let canvasView else { return }
        try canvasView.throwIfUnsavedDrawing()
        update(id, isVisible: isVisible)
        try await canvasView.updateFullCanvas()
    }

    func setAlpha(id: LayerId, alpha: Int) {
        guard let canvasView else { return }
        update(id, alpha: alpha)
        canvasView.updateCanvasDisplay()
    }

    func setAlphaSliderDragging(_ isDragging: Bool) {}

    func updateLayerThumbnail(_ id: UUID, thumbnail: UIImage?) {
        guard
            let thumbnail,
            layerModels.firstIndex(where: { $0.id == id }) != nil
        else { return }
        thumbnails[id] = thumbnail
    }
}

private extension TextureLayersState {
    func insertLayer(
        layer: TextureLayerModel,
        thumbnail: UIImage?,
        at index: Int
    ) {
        layerModels.insert(layer, at: index)
        if let thumbnail {
            thumbnails[layer.id] = thumbnail
        }
        selectedLayerId = layer.id
    }

    @discardableResult
    func removeLayer(layerIndexToDelete index: Int) -> Bool {
        guard
            layerModels.count > 1,
            layerModels.indices.contains(index)
        else { return false }

        let newLayerId = layerModels[
            RemoveLayerIndex.nextLayerIndexAfterDeletion(index: index)
        ].id

        let removed = layerModels.remove(at: index)
        thumbnails[removed.id] = nil
        selectedLayerId = newLayerId
        return true
    }

    func moveLayer(indices: MoveLayerIndices) {
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: layerModels.count
        )
        layerModels.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )
    }

    func selectLayer(_ id: LayerId) {
        selectedLayerId = id
    }

    func update(
        _ id: LayerId,
        title: String? = nil,
        alpha: Int? = nil,
        isVisible: Bool? = nil,
        thumbnail: UIImage? = nil
    ) {
        guard
            let index = layerModels.firstIndex(where: { $0.id == id })
        else { return }

        if title != nil || alpha != nil || isVisible != nil {
            let layer = layerModels[index]
            layerModels[index] = .init(
                id: layer.id,
                title: title ?? layer.title,
                alpha: alpha ?? layer.alpha,
                isVisible: isVisible ?? layer.isVisible
            )
        }
        if let thumbnail {
            thumbnails[id] = thumbnail
        }
    }
}

// MARK: - Undo replay

extension TextureLayersState {

    /// Applies layer list changes for undo/redo without `throwIfUnsavedDrawing`.
    func insertLayerForUndo(
        layer: TextureLayerModel,
        thumbnail: UIImage?,
        at index: Int
    ) {
        insertLayer(layer: layer, thumbnail: thumbnail, at: index)
    }

    @discardableResult
    func removeLayerForUndo(layerIndexToDelete index: Int) -> Bool {
        removeLayer(layerIndexToDelete: index)
    }

    func moveLayerForUndo(indices: MoveLayerIndices) {
        moveLayer(indices: indices)
    }

    func selectLayerForUndo(_ id: LayerId) {
        selectLayer(id)
    }

    func updateForUndo(
        _ id: LayerId,
        title: String? = nil,
        alpha: Int? = nil,
        isVisible: Bool? = nil,
        thumbnail: UIImage? = nil
    ) {
        update(id, title: title, alpha: alpha, isVisible: isVisible, thumbnail: thumbnail)
    }
}
