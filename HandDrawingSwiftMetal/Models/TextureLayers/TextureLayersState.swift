//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

@MainActor
class TextureLayersState: ObservableObject, TextureLayersStateProtocol {

    var selectedLayer: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layerModels.first(where: { $0.id == selectedLayerId })
    }

    var selectedLayerIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layerModels.firstIndex(where: { $0.id == selectedLayerId })
    }

    var layerSnapshots: [CanvasLayerSnapshot] {
        layerModels.map {
            .init(id: $0.id, alpha: $0.alpha, isVisible: $0.isVisible)
        }
    }

    var selectedLayerSnapshot: CanvasLayerSnapshot? {
        guard let selectedLayer else { return nil }
        return .init(
            id: selectedLayer.id,
            alpha: selectedLayer.alpha,
            isVisible: selectedLayer.isVisible
        )
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

    private let repository: TextureLayersDocumentsRepositoryProtocol?

    private var device: MTLDevice?

    private var commandQueue: MTLCommandQueue?

    private(set) weak var canvasView: (any TextureLayerCanvasUpdating)?

    init(
        repository: TextureLayersDocumentsRepositoryProtocol? = nil
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
    ) {
        setLayers(
            textureLayers.layers,
            textureSize: textureLayers.textureSize,
            selectedIndex: textureLayers.layerIndex
        )
    }

    func setLayers(
        _ layers: [TextureLayerModel],
        textureSize: CGSize,
        selectedIndex: Int = 0
    ) {
        layerModels = layers
        thumbnails = [:]
        if layers.isEmpty {
            selectedLayerId = nil
        } else {
            let index = max(0, min(selectedIndex, layers.count - 1))
            selectedLayerId = layers[index].id
        }
        self.textureSize = textureSize
    }

    func addLayer() async throws {
        guard
            let repository,
            let device,
            let commandQueue,
            let canvasView
        else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }
        guard let anchorId = selectedLayerId else { return }

        let id = LayerId()
        guard let texture = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        ) else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }
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
        updateFullCanvas(canvasView)
    }

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

    func removeLayer(id: LayerId) async throws -> Bool {
        guard
            canvasView != nil,
            let repository,
            layerModels.count > 1,
            let index = layerModels.firstIndex(where: { $0.id == id }),
            try repository.removeTexture(id)
        else { return false }

        let removed = removeLayer(layerIndexToDelete: index)
        if removed {
            refreshCanvas()
        }
        return removed
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

    func renameLayer(id: LayerId, title: String) throws {
        update(id, title: title)
    }

    func moveLayers(from source: IndexSet, to destination: Int) throws {
        moveLayer(
            indices: .init(
                sourceIndexSet: source,
                destinationIndex: destination
            )
        )
        refreshCanvas()
    }

    func selectLayer(id: LayerId) throws {
        selectLayer(id)
        refreshCanvas()
    }

    func setVisibility(id: LayerId, isVisible: Bool) throws {
        update(id, isVisible: isVisible)
        refreshCanvas()
    }

    func setAlpha(id: LayerId, alpha: Int) {
        update(id, alpha: alpha)
        canvasView?.updateCanvasDisplay()
    }

    func setAlphaSliderDragging(_ isDragging: Bool) {}

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

    func updateLayerThumbnail(_ id: UUID, thumbnail: UIImage?) {
        guard
            let thumbnail,
            layerModels.firstIndex(where: { $0.id == id }) != nil
        else { return }
        thumbnails[id] = thumbnail
    }

    func refreshCanvas() {
        guard let canvasView else { return }
        updateFullCanvas(canvasView)
    }
}

private extension TextureLayersState {
    func updateFullCanvas(_ canvasView: any TextureLayerCanvasUpdating) {
        Task {
            try? await canvasView.updateFullCanvas()
        }
    }
}
