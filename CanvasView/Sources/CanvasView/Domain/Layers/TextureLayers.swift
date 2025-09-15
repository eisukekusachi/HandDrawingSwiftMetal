//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// A store that manages the layer stack of a canvas
public final class TextureLayers: TextureLayersProtocol, ObservableObject {
    /// Emits when a canvas update is requested
    public var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        canvasUpdateRequestedSubject.eraseToAnyPublisher()
    }
    private let canvasUpdateRequestedSubject = PassthroughSubject<Void, Never>()

    /// Emits when a full canvas update is requested
    public var fullCanvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        fullCanvasUpdateRequestedSubject.eraseToAnyPublisher()
    }
    private let fullCanvasUpdateRequestedSubject = PassthroughSubject<Void, Never>()

    /// Emits whenever `layers` change
    public var layersPublisher: AnyPublisher<[TextureLayerItem], Never> {
        $_layers.eraseToAnyPublisher()
    }

    /// Emits whenever `selectedLayerId` change
    public var selectedLayerIdPublisher: AnyPublisher<UUID?, Never> {
        $_selectedLayerId.eraseToAnyPublisher()
    }

    /// Emits whenever `textureSize` change
    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        $_textureSize.eraseToAnyPublisher()
    }

    private var textureRepository: TextureRepository?

    private var undoStack: UndoStack?

    @Published private var _layers: [TextureLayerItem] = []

    @Published private var _selectedLayerId: UUID?

    // Set a default value to avoid nil
    @Published private var _textureSize: CGSize = .init(width: 768, height: 1024)

    private var oldAlpha: Int?

    public init() {}
}

public extension TextureLayers {

    var textureSize: CGSize {
        _textureSize
    }

    var layers: [TextureLayerItem] {
        _layers
    }

    var layerCount: Int {
        _layers.count
    }

    var selectedLayerId: UUID? {
        _selectedLayerId
    }

    var selectedLayer: TextureLayerItem? {
        guard let _selectedLayerId else { return nil }
        return _layers.first(where: { $0.id == _selectedLayerId })
    }

    var selectedIndex: Int? {
        guard let _selectedLayerId else { return nil }
        return _layers.firstIndex(where: { $0.id == _selectedLayerId })
    }

    func layer(_ layerId: UUID) -> TextureLayerItem? {
        _layers.first(where: { $0.id == layerId })
    }
}

@MainActor
public extension TextureLayers {

    func initialize(
        configuration: ResolvedTextureLayserArrayConfiguration,
        textureRepository: TextureRepository? = nil,
        undoStack: UndoStack? = nil
    ) async {
        self._textureSize = configuration.textureSize

        self._layers = configuration.layers.map {
            .init(
                id: $0.id,
                title: $0.title,
                alpha: $0.alpha,
                isVisible: $0.isVisible,
                thumbnail: nil
            )
        }

        self._selectedLayerId = configuration.selectedLayerId

        self.textureRepository = textureRepository

        Task {
            let textures = try await textureRepository?.copyTextures(uuids: _layers.map { $0.id })
            textures?.forEach { [weak self] texture in
                self?.updateThumbnail(texture)
            }
        }
    }

    func addLayer(layer: TextureLayerItem, texture: MTLTexture?, at index: Int) async throws {
        guard
            let textureRepository,
            let previousLayerIndex = selectedIndex
        else { return }

        self._layers.insert(layer, at: index)

        try? await Task.sleep(nanoseconds: 1_000_000)

        selectLayer(id: layer.id)

        try await textureRepository
            .addTexture(
                texture,
                newTextureUUID: layer.id
            )

        guard
            let currentLayerIndex = selectedIndex,
            let object = undoAdditionObject(
                previousLayerIndex: previousLayerIndex,
                currentLayerIndex: currentLayerIndex,
                layer: .init(item: layer),
                texture: texture
            )
        else { return }

        undoStack?.pushUndoObject(object)
    }

    func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            let textureRepository,
            let _selectedLayerId,
            let selectedLayer,
            let selectedIndex
        else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: index)

        _layers.remove(at: index)

        try? await Task.sleep(nanoseconds: 1_000_000)

        selectLayer(id: _layers[newLayerIndex].id)

        let result = try await textureRepository.copyTexture(
            uuid: _selectedLayerId
        )

        textureRepository
            .removeTexture(selectedLayer.id)

        guard let object = undoDeletionObject(
            previousLayerIndex: selectedIndex,
            currentLayerIndex: newLayerIndex,
            layer: .init(
                fileName: selectedLayer.fileName,
                title: selectedLayer.title,
                alpha: selectedLayer.alpha,
                isVisible: selectedLayer.isVisible
            ),
            texture: result.texture
        )
        else { return }

        undoStack?.pushUndoObject(object)
    }

    func moveLayer(indices: MoveLayerIndices) {
        // Reverse index to match reversed layer order
        let reversedIndices = MoveLayerIndices.reversedIndices(
            indices: indices,
            layerCount: self._layers.count
        )

        self._layers.move(
            fromOffsets: reversedIndices.sourceIndexSet,
            toOffset: reversedIndices.destinationIndex
        )

        fullCanvasUpdateRequestedSubject.send(())

        guard
            let selectedLayerId = selectedLayer?.id,
            let textureLayer = _layers.first(where: { $0.id == selectedLayerId }),
            let object = undoMoveObject(
                indices: MoveLayerIndices.reversedIndices(
                    indices: indices,
                    layerCount: _layers.count
                ),
                selectedLayerId: selectedLayerId,
                textureLayer: .init(
                    fileName: textureLayer.fileName,
                    title: textureLayer.title,
                    alpha: textureLayer.alpha,
                    isVisible: textureLayer.isVisible
                )
            )
        else { return }

        undoStack?.pushUndoObject(object)
    }

    func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        guard let index = _layers.firstIndex(where: { $0.id == identifiedTexture.uuid }) else { return }
        self._layers[index].thumbnail = identifiedTexture.texture.makeThumbnail()
    }

    func selectLayer(id: UUID) {
        _selectedLayerId = id
        fullCanvasUpdateRequestedSubject.send(())
    }

    func updateTitle(id: UUID, title: String) {
        guard
            let selectedIndex = _layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = _layers[selectedIndex]

        _layers[selectedIndex] = .init(
            id: layer.id,
            title: title,
            alpha: layer.alpha,
            isVisible: layer.isVisible,
            thumbnail: layer.thumbnail
        )
    }

    func updateVisibility(id: UUID, isVisible: Bool) {
        guard
            let selectedIndex = _layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = _layers[selectedIndex]

        _layers[selectedIndex] = .init(
            id: layer.id,
            title: layer.title,
            alpha: layer.alpha,
            isVisible: isVisible,
            thumbnail: layer.thumbnail
        )

        // Since visibility can update layers that are not selected, the entire canvas needs to be updated.
        fullCanvasUpdateRequestedSubject.send(())
    }

    func updateAlpha(id: UUID, alpha: Int, isStartHandleDragging: Bool) {
        guard
            let selectedIndex = _layers.map({ $0.id }).firstIndex(of: id)
        else { return }

        let layer = _layers[selectedIndex]

        _layers[selectedIndex] = .init(
            id: layer.id,
            title: layer.title,
            alpha: alpha,
            isVisible: layer.isVisible,
            thumbnail: layer.thumbnail
        )

        // Only the alpha of the selected layer can be changed, so other layers will not be updated
        canvasUpdateRequestedSubject.send(())
    }
}

@MainActor
public extension TextureLayers {

    func undoAlphaObject(dragging: Bool) -> UndoStackModel<UndoObject>? {
        var undoObject: UndoObject? = nil
        var redoObject: UndoObject? = nil

        if dragging, let alpha = selectedLayer?.alpha {
            self.oldAlpha = alpha

        } else {
            if let oldAlpha = self.oldAlpha,
               let newAlpha = selectedLayer?.alpha,
               let selectedLayer = selectedLayer {

                undoObject = UndoAlphaChangedObject(
                    layer: .init(item: selectedLayer),
                    withNewAlpha: Int(oldAlpha)
                )

                redoObject = UndoAlphaChangedObject(
                    layer: .init(item: selectedLayer),
                    withNewAlpha: newAlpha
                )
            }

            self.oldAlpha = nil
        }

        guard
            let undoObject,
            let redoObject
        else { return nil }

        return .init(
            undoObject: undoObject,
            redoObject: redoObject
        )
    }

    func undoAdditionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) -> UndoStackModel<UndoObject>? {
        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: _layers[previousLayerIndex].id
        )

        return .init(
            undoObject: undoObject,
            redoObject: redoObject,
            texture: texture
        )
    }

    func undoDeletionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) -> UndoStackModel<UndoObject>? {
        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: _layers[currentLayerIndex].id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: redoObject.textureLayer,
            insertIndex: previousLayerIndex
        )

        return .init(
            undoObject: undoObject,
            redoObject: redoObject,
            texture: texture
        )
    }

    func undoMoveObject(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        textureLayer: TextureLayerModel
    ) -> UndoStackModel<UndoObject>? {
        let redoObject = UndoMoveObject(
            indices: indices,
            selectedLayerId: selectedLayerId,
            layer: textureLayer
        )

        let undoObject = redoObject.reversedObject

        return .init(
            undoObject: undoObject,
            redoObject: redoObject
        )
    }
}
