//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/13.
//

import Combine
import UIKit

/// A class that manages texture layers
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

    /// Copies a texture for the given UUID
    func duplicatedTexture(id: UUID) async throws -> IdentifiedTexture? {
        try await textureRepository?.copyTexture(uuid: id)
    }
}

@MainActor
public extension TextureLayers {

    func initialize(
        configuration: ResolvedTextureLayerArrayConfiguration,
        textureRepository: TextureRepository? = nil
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

    func addLayer(layer: TextureLayerItem, texture: MTLTexture, at index: Int) async throws {
        guard let textureRepository else { return }

        self._layers.insert(layer, at: index)

        _selectedLayerId = layer.id

        try await textureRepository
            .addTexture(
                texture,
                newTextureUUID: layer.id
            )

        fullCanvasUpdateRequestedSubject.send(())
    }

    func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            let textureRepository,
            let selectedLayer,
            _layers.count > 1
        else { return }

        let newLayerIndex = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: index)
        let newLayerId = _layers[newLayerIndex].id

        _layers.remove(at: index)

        _selectedLayerId = newLayerId

        try textureRepository
            .removeTexture(selectedLayer.id)

        fullCanvasUpdateRequestedSubject.send(())
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
    }

    func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        guard let index = _layers.firstIndex(where: { $0.id == identifiedTexture.uuid }) else { return }
        self._layers[index].thumbnail = identifiedTexture.texture.makeThumbnail()
    }

    func selectLayer(id: UUID) {
        _selectedLayerId = id

        fullCanvasUpdateRequestedSubject.send(())
    }

    func updateLayer(_ layer: TextureLayerItem) {
        guard
            let selectedIndex = _layers.firstIndex(where: { $0.id == layer.id })
        else {
            Logger.error(String(localized: "Unable to find the index of the textureLayer to update", bundle: .module))
            return
        }

        _layers[selectedIndex] = layer
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

    func updateAlpha(id: UUID, alpha: Int) {
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

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    func beginAlphaChange() {
        // Do nothing
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    func endAlphaChange() {
        // Do nothing
    }

    /// Requests a partial canvas update
    func requestCanvasUpdate() {
        canvasUpdateRequestedSubject.send(())
    }

    /// Requests a full canvas update (all layers composited)
    func requestFullCanvasUpdate() {
        fullCanvasUpdateRequestedSubject.send(())
    }

    func addTexture(_ texture: any MTLTexture, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        guard let textureRepository else {
            throw unwrappingError
        }
        return try await textureRepository.addTexture(texture, newTextureUUID: uuid)
    }

    func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) async throws -> IdentifiedTexture {
        guard let textureRepository else {
            throw unwrappingError
        }
        return try await textureRepository.updateTexture(texture: texture, for: uuid)
    }

    func removeTexture(_ uuid: UUID) throws -> UUID {
        guard let textureRepository else {
            throw unwrappingError
        }
        return try textureRepository.removeTexture(uuid)
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

    private var unwrappingError: NSError {
        let error = NSError(
            title: String(localized: "Error", bundle: .module),
            message: String(localized: "Failed to unwrap texture repository", bundle: .module)
        )
        Logger.error(error)
        return error
    }
}
