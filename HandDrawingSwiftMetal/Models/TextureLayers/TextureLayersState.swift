//
//  TextureLayersState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/10/02.
//

import CanvasView
import Combine
import Core
import TextureLayerCanvasView
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

@MainActor
public final class TextureLayersState: ObservableObject, TextureLayersProtocol, TextureLayerCanvasProtocol {

    var selectedLayer: TextureLayerModel? {
        guard let selectedLayerId else { return nil }
        return layerModels.first(where: { $0.id == selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let selectedLayerId else { return nil }
        return layerModels.firstIndex(where: { $0.id == selectedLayerId })
    }

    public var selectedLayerIndex: Int? {
        selectedIndex
    }

    var layerCount: Int {
        layerModels.count
    }

    public var layerSnapshots: [CanvasLayerSnapshot] {
        layerModels.map {
            .init(id: $0.id, alpha: $0.alpha, isVisible: $0.isVisible)
        }
    }

    public var selectedLayerSnapshot: CanvasLayerSnapshot? {
        guard let selectedLayer else { return nil }
        return .init(
            id: selectedLayer.id,
            alpha: selectedLayer.alpha,
            isVisible: selectedLayer.isVisible
        )
    }

    /// Snapshot of the current layers for persistence or handoff.
    var snapshot: TextureLayersSnapshot {
        .init(
            layers: layerModels,
            layerIndex: selectedIndex ?? 0,
            textureSize: textureSize
        )
    }

    /// Presentation models for `TextureLayerView`.
    public var layers: [TextureLayerItem] {
        layerModels.map { model in
            .init(model: model, thumbnail: thumbnails[model.id])
        }
    }

    @Published private(set) var layerModels: [TextureLayerModel] = []

    @Published private var thumbnails: [LayerId: UIImage] = [:]

    @Published public private(set) var selectedLayerId: LayerId?

    @Published public private(set) var textureSize: CGSize = .init(width: 768, height: 1024)

    private let repository: TextureLayersDocumentsRepositoryProtocol?

    private var device: MTLDevice?

    private var commandQueue: MTLCommandQueue?

    private var undo: UndoTextureLayerRegistrar?

    private var showError: (Error) -> Void = { _ in }

    private weak var canvasView: TextureLayerCanvasView?

    public init(
        repository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.repository = repository
    }

    /// Canvas and undo are created from this object, so they are set up once both exist.
    func setup(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        undo: UndoTextureLayerRegistrar,
        canvasView: TextureLayerCanvasView,
        showError: @escaping (Error) -> Void
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.undo = undo
        self.canvasView = canvasView
        self.showError = showError
    }

    /// Restores the layer list from a saved snapshot.
    func update(
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

    public func addLayer() async throws {
        guard
            let repository,
            let device,
            let commandQueue,
            let undo,
            let canvasView
        else {
            throw NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to load required data")
            )
        }
        guard let anchorId = selectedLayerId else { return }

        let id = LayerId()
        do {
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
            guard let anchorIndex = index(for: anchorId) else {
                try repository.removeTexture(id)
                return
            }
            addLayer(
                layer: .init(
                    id: id,
                    title: TimeStampFormatter.currentDate,
                    alpha: 255,
                    isVisible: true
                ),
                thumbnail: texture.makeThumbnail(),
                at: AddLayerIndex.insertIndex(selectedIndex: anchorIndex)
            )
            await undo.didAddLayer(in: self)
            updateFullCanvas(canvasView)
        } catch {
            showError(error)
            throw error
        }
    }

    public func removeLayer(id: LayerId) async throws -> Bool {
        guard let repository, let undo, let canvasView else { return false }
        do {
            let removed = try await undo.removeLayer(in: self) {
                guard layerCount > 1, let index = index(for: id) else { return false }
                guard try repository.removeTexture(id) else { return false }
                return removeLayer(layerIndexToDelete: index)
            }
            if removed {
                updateFullCanvas(canvasView)
            }
            return removed
        } catch {
            showError(error)
            throw error
        }
    }

    public func renameLayer(id: LayerId, title: String) throws {
        if let undo {
            try undo.renameLayer(in: self, id: id, title: title) {
                update(id, title: title)
            }
        } else {
            update(id, title: title)
        }
    }

    public func moveLayers(from source: IndexSet, to destination: Int) throws {
        if let undo {
            try undo.moveLayer(in: self, source: source, destination: destination) {
                moveLayer(
                    indices: .init(
                        sourceIndexSet: source,
                        destinationIndex: destination
                    )
                )
            }
        } else {
            moveLayer(
                indices: .init(
                    sourceIndexSet: source,
                    destinationIndex: destination
                )
            )
        }
        if let canvasView {
            updateFullCanvas(canvasView)
        }
    }

    public func selectLayer(id: LayerId) {
        if let undo {
            undo.selectLayer(in: self, id: id) {
                selectLayer(id)
            }
        } else {
            selectLayer(id)
        }
        if let canvasView {
            updateFullCanvas(canvasView)
        }
    }

    public func setVisibility(id: LayerId, isVisible: Bool) {
        if let undo {
            undo.changeVisibility(in: self, id: id, isVisible: isVisible) {
                update(id, isVisible: isVisible)
            }
        } else {
            update(id, isVisible: isVisible)
        }
        if let canvasView {
            updateFullCanvas(canvasView)
        }
    }

    public func setAlpha(id: LayerId, alpha: Int) {
        updateAlpha(id, alpha: alpha)
        canvasView?.updateCanvasTextureUsingCurrentTexture()
    }

    public func setAlphaSliderDragging(_ isDragging: Bool) {
        undo?.alphaSliderDraggingChanged(in: self, isDragging)
    }

    public func updateLayerThumbnail(_ id: UUID, thumbnail: UIImage?) {
        updateThumbnail(id, thumbnail: thumbnail)
    }

    private func updateFullCanvas(_ canvasView: TextureLayerCanvasView) {
        Task {
            try? await canvasView.updateFullCanvasTexture()
        }
    }
}

extension TextureLayersState {

    func addLayer(
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
        guard layerCount > 1, layerModels.indices.contains(index) else { return false }

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
            layerCount: layerCount
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
        guard let index = index(for: id) else { return }

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

    func updateAlpha(_ id: LayerId, alpha: Int) {
        update(id, alpha: alpha)
    }

    func updateThumbnail(_ id: LayerId, thumbnail: UIImage?) {
        guard let thumbnail, index(for: id) != nil else { return }
        thumbnails[id] = thumbnail
    }

    func index(for id: LayerId) -> Int? {
        layerModels.firstIndex(where: { $0.id == id })
    }

    func layer(_ id: LayerId) -> TextureLayerModel? {
        layerModels.first(where: { $0.id == id })
    }
}
