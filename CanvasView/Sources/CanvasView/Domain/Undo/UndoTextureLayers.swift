//
//  UndoTextureLayers.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/23.
//

import Combine
import UIKit

/// A class that manages texture layers
public final class UndoTextureLayers: TextureLayersProtocol, ObservableObject {

    @Published private var textureLayers: any TextureLayersProtocol

    private let undoManager = UndoManager()

    private var undoTextureRepository: TextureRepository? = nil

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject: PassthroughSubject<UndoRedoButtonState, Never> = .init()

    /// An undo object captured at the start of the stroke, shown when undo is triggered.
    private var drawingUndoObject: UndoObject?

    private var oldAlpha: Int?

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: any TextureLayersProtocol
    ) {
        self.textureLayers = textureLayers
    }

    func initialize(_ size: CGSize) {
        reset()
        undoTextureRepository?.setTextureSize(size)
    }

    func undo() {
        undoManager.undo()
        didUndoSubject.send(.init(undoManager))
    }
    func redo() {
        undoManager.redo()
        didUndoSubject.send(.init(undoManager))
    }
    func reset() {
        undoManager.removeAllActions()
        undoTextureRepository?.removeAll()
        didUndoSubject.send(.init(undoManager))
        cancellables = Set<AnyCancellable>()
    }
}

extension UndoTextureLayers {

    public var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        textureLayers.canvasUpdateRequestedPublisher
    }

    public var fullCanvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        textureLayers.fullCanvasUpdateRequestedPublisher
    }

    public var layersPublisher: AnyPublisher<[TextureLayerItem], Never> {
        textureLayers.layersPublisher
    }

    public var selectedLayerIdPublisher: AnyPublisher<UUID?, Never> {
        textureLayers.selectedLayerIdPublisher
    }

    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        textureLayers.textureSizePublisher
    }

    public var selectedLayer: TextureLayerItem? {
        textureLayers.selectedLayer
    }

    public var selectedIndex: Int? {
        textureLayers.selectedIndex
    }

    public var layers: [TextureLayerItem] {
        textureLayers.layers
    }

    public var layerCount: Int {
        textureLayers.layerCount
    }

    public var textureSize: CGSize {
        textureLayers.textureSize
    }

    public func initialize(configuration: ResolvedTextureLayerArrayConfiguration, textureRepository: (any TextureRepository)?) async {
        await textureLayers.initialize(configuration: configuration, textureRepository: textureRepository)
    }

    public func layer(_ layerId: UUID) -> TextureLayerItem? {
        textureLayers.layer(layerId)
    }

    public func selectLayer(_ id: UUID) {
        textureLayers.selectLayer(id)
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        textureLayers.updateLayer(layer)
    }

    public func updateThumbnail(_ id: UUID, texture: MTLTexture) {
        textureLayers.updateThumbnail(id, texture: texture)
    }

    public func updateTitle(_ id: UUID, title: String) {
        textureLayers.updateTitle(id, title: title)
    }

    public func updateVisibility(_ id: UUID, isVisible: Bool) {
        textureLayers.updateVisibility(id, isVisible: isVisible)
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }

    public func duplicatedTexture(_ id: UUID) async throws -> IdentifiedTexture? {
        try await textureLayers.duplicatedTexture(id)
    }

    public func addTexture(_ texture: any MTLTexture, id: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.addTexture(texture, id: id)
    }

    public func updateTexture(texture: (any MTLTexture)?, for id: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.updateTexture(texture: texture, for: id)
    }

    public func removeTexture(_ id: UUID) throws -> UUID {
        try textureLayers.removeTexture(id)
    }
}

extension UndoTextureLayers {
    public func setUndoTextureRepository(
        undoCount: Int = 64,
        undoTextureRepository: TextureRepository,
    ) {
        self.undoTextureRepository = undoTextureRepository

        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    public func addLayer(layer: TextureLayerItem, texture: MTLTexture, at index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: .init(item: layer),
            at: index
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: .init(item: layer),
            selectedLayerIdAfterDeletion: selectedLayer.id
        )

        try await textureLayers.addLayer(layer: layer, texture: texture, at: index)

        await pushUndoAdditionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }
    
    public func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let identifiedTexture = try await textureLayers.duplicatedTexture(selectedLayer.id)
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: .init(item: selectedLayer),
            selectedLayerIdAfterDeletion: selectedLayer.id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: redoObject.textureLayer,
            at: index
        )

        try await textureLayers.removeLayer(layerIndexToDelete: index)

        await pushUndoDeletionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: identifiedTexture.texture
            )
        )
    }
    
    public func moveLayer(indices: MoveLayerIndices) {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let redoObject = UndoMoveObject(
            indices: indices,
            selectedLayerId: selectedLayer.id,
            layer: .init(item: selectedLayer)
        )

        let undoObject = redoObject.reversedObject

        textureLayers.moveLayer(indices: indices)

        pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    public func updateAlpha(_ id: UUID, alpha: Int) {
        textureLayers.updateAlpha(id, alpha: alpha)
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        setAlphaUndoObject()
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        pushUndoAlphaObject()
    }
}

extension UndoTextureLayers {
    func setDrawingUndoObject() async {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        do {
            if let result = try await textureLayers.duplicatedTexture(selectedLayer.id) {
                let undoObject = UndoDrawingObject(
                    from: .init(item: selectedLayer)
                )

                try await undoTextureRepository?.addTexture(
                    result.texture,
                    id: undoObject.undoTextureUUID
                )
                drawingUndoObject = undoObject
            }
        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDrawingObject(
        texture: MTLTexture
    ) async {
        guard
            let undoObject = drawingUndoObject,
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let redoObject = UndoDrawingObject(
            from: .init(item: selectedLayer)
        )

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    texture,
                    id: redoObject.undoTextureUUID
                )

            pushUndoObject(
                .init(
                    undoObject: undoObject,
                    redoObject: redoObject
                )
            )

            drawingUndoObject = nil

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoAdditionObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) async {
        guard
            let undoTexture = undoRedoObject.texture
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "undoRedoObject.texture"))
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    undoTexture,
                    id: undoRedoObject.redoObject.undoTextureUUID
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDeletionObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) async {
        guard
            let undoTexture = undoRedoObject.texture
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "undoRedoObject.texture"))
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    undoTexture,
                    id: undoRedoObject.undoObject.undoTextureUUID
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    public func setAlphaUndoObject() {
        guard let alpha = textureLayers.selectedLayer?.alpha else { return }
        self.oldAlpha = alpha
    }
    public func pushUndoAlphaObject() {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }
        guard
            let oldAlpha = self.oldAlpha,
            oldAlpha != selectedLayer.alpha
        else { return }

        let undoObject = UndoAlphaChangedObject(
            layer: .init(item: selectedLayer),
            withNewAlpha: Int(oldAlpha)
        )
        let redoObject = UndoAlphaChangedObject(
            layer: undoObject.textureLayer,
            withNewAlpha: selectedLayer.alpha
        )

        pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )

        self.oldAlpha = nil
    }

    private func pushUndoObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) {
        let undoObject = undoRedoObject.undoObject
        let redoObject = undoRedoObject.redoObject

        undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                _ = try? self?.undoTextureRepository?.removeTexture(
                    result.undoTextureUUID
                )
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                _ = try? self?.undoTextureRepository?.removeTexture(
                    result.undoTextureUUID
                )
            })
            .store(in: &cancellables)

        pushUndoObjectToUndoStack(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }
}

extension UndoTextureLayers {

    private func pushUndoObjectToUndoStack(
        _ undoStack: UndoStackModel<UndoObject>
    ) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.performUndo(undoStack.undoObject)

            // Redo Registration
            self?.pushUndoObject(undoStack.reversedObject)
        }
        undoManager.endUndoGrouping()
        didUndoSubject.send(.init(undoManager))
    }

    private func performUndo(
        _ undoObject: UndoObject
    ) {
        Task {
            do {
                try await performTextureOperation(
                    undoObject: undoObject,
                    undoTextureRepository: undoTextureRepository
                )
            } catch {
                Logger.error(error)
            }
        }
    }

    public func performTextureOperation(
        undoObject: UndoObject,
        undoTextureRepository: TextureRepository?
    ) async throws {
        guard let undoTextureRepository else { return }

        if let undoObject = undoObject as? UndoDrawingObject {
            let result = try await undoTextureRepository.duplicatedTexture(undoObject.undoTextureUUID)

            let textureLayerId = undoObject.textureLayer.id

            try await textureLayers.updateTexture(
                texture: result.texture,
                for: textureLayerId
            )

            textureLayers.updateThumbnail(textureLayerId, texture: result.texture)
            textureLayers.selectLayer(textureLayerId)
            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoAdditionObject {
            let result = try await undoTextureRepository
                .duplicatedTexture(undoObject.undoTextureUUID)

            let textureLayer = undoObject.textureLayer
            let texture = result.texture

            try await textureLayers.addLayer(
                layer: .init(
                    model: textureLayer,
                    thumbnail: texture.makeThumbnail()
                ),
                texture: texture,
                at: undoObject.insertIndex
            )
            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoDeletionObject {
            guard
                let index = textureLayers.layers.firstIndex(where: { $0.id == undoObject.textureLayer.id })
            else {
                Logger.error(String(localized: "Unable to find the index of the textureLayer to remove while undoing", bundle: .module))
                return
            }

            try await textureLayers.removeLayer(
                layerIndexToDelete: index
            )
            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoMoveObject {
            textureLayers.moveLayer(
                indices: undoObject.indices
            )
            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoAlphaChangedObject {
            guard let result = try await textureLayers.duplicatedTexture(undoObject.textureLayer.id) else { return }

            textureLayers.updateLayer(
                .init(
                    model: undoObject.textureLayer,
                    thumbnail: result.texture.makeThumbnail()
                )
            )
            textureLayers.requestFullCanvasUpdate()
        }
    }
}
