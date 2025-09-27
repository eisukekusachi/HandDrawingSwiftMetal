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

    public func duplicatedTexture(id: UUID) async throws -> IdentifiedTexture? {
        try await textureLayers.duplicatedTexture(id: id)
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

    public func selectLayer(id: UUID) {
        textureLayers.selectLayer(id: id)
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        textureLayers.updateLayer(layer)
    }

    public func updateTitle(id: UUID, title: String) {
        textureLayers.updateTitle(id: id, title: title)
    }

    public func updateVisibility(id: UUID, isVisible: Bool) {
        textureLayers.updateVisibility(id: id, isVisible: isVisible)
    }

    public func updateThumbnail(_ identifiedTexture: IdentifiedTexture) {
        textureLayers.updateThumbnail(identifiedTexture)
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }

    public func addTexture(_ texture: any MTLTexture, newTextureUUID uuid: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.addTexture(texture, newTextureUUID: uuid)
    }

    public func updateTexture(texture: (any MTLTexture)?, for uuid: UUID) async throws -> IdentifiedTexture {
        try await textureLayers.updateTexture(texture: texture, for: uuid)
    }

    public func removeTexture(_ uuid: UUID) throws -> UUID {
        try textureLayers.removeTexture(uuid)
    }
}

extension UndoTextureLayers {
    public func setUndoStack(
        undoCount: Int = 64,
        undoTextureRepository: TextureRepository,
    ) {
        self.undoTextureRepository = undoTextureRepository

        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    public func addLayer(layer: TextureLayerItem, texture: any MTLTexture, at index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(localized: "Unable to find the selectedLayer", bundle: .module))
            return
        }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: .init(item: layer),
            insertIndex: index
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
            let identifiedTexture = try await textureLayers.duplicatedTexture(id: selectedLayer.id)
        else {
            Logger.error(String(localized: "Unable to find the selectedLayer", bundle: .module))
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
            insertIndex: index
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
            Logger.error(String(localized: "Unable to find the selectedLayer", bundle: .module))
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

    public func updateAlpha(id: UUID, alpha: Int, isStartHandleDragging: Bool) {
        textureLayers.updateAlpha(id: id, alpha: alpha, isStartHandleDragging: isStartHandleDragging)

        if isStartHandleDragging, let alpha = textureLayers.selectedLayer?.alpha {
            self.oldAlpha = alpha
        }

        if let oldAlpha = self.oldAlpha,
           let selectedLayer = textureLayers.selectedLayer {

            let undoObject = UndoAlphaChangedObject(
                layer: .init(item: selectedLayer),
                withNewAlpha: Int(oldAlpha)
            )

            pushUndoObject(
                .init(
                    undoObject: undoObject,
                    redoObject: UndoAlphaChangedObject(
                        layer: undoObject.textureLayer,
                        withNewAlpha: selectedLayer.alpha
                    )
                )
            )
        }
    }
}

extension UndoTextureLayers {
    func setDrawingUndoObject() async {
        guard
            let undoLayer = textureLayers.selectedLayer
        else { return }

        do {
            if let result = try await textureLayers.duplicatedTexture(id: undoLayer.id) {
                let undoObject = UndoDrawingObject(
                    from: .init(item: undoLayer)
                )

                try await undoTextureRepository?.addTexture(
                    result.texture,
                    newTextureUUID: undoObject.undoTextureUUID
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
            let redoLayer = textureLayers.selectedLayer
        else { return }

        let redoObject = UndoDrawingObject(
            from: .init(item: redoLayer)
        )

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    texture,
                    newTextureUUID: redoObject.undoTextureUUID
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
        guard let undoTexture = undoRedoObject.texture else { return }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    undoTexture,
                    newTextureUUID: undoRedoObject.redoObject.undoTextureUUID
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
        guard let undoTexture = undoRedoObject.texture else { return }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    undoTexture,
                    newTextureUUID: undoRedoObject.undoObject.undoTextureUUID
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }
}

extension UndoTextureLayers {
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

        let undoStack: UndoStackModel<UndoObject> = .init(
            undoObject: undoObject,
            redoObject: redoObject
        )
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { target in
            Task { @MainActor in
                do {
                    try await target.didPerformUndo(undoStack.undoObject)
                } catch {
                    Logger.error(error)
                }

                // Redo Registration
                target.pushUndoObject(
                    undoStack.reversedObject
                )
            }
        }
        undoManager.endUndoGrouping()
        didUndoSubject.send(
            .init(undoManager)
        )
    }

    private func didPerformUndo(_ undoObject: UndoObject) async throws {
        guard let undoTextureRepository else { return }

        if let undoObject = undoObject as? UndoDrawingObject {
            let undoRepositoryUUID = undoObject.undoTextureUUID
            let textureLayerId = undoObject.textureLayer.id

            let result = try await undoTextureRepository.copyTexture(uuid: undoRepositoryUUID)

            try await textureLayers.updateTexture(
                texture: result.texture,
                for: textureLayerId
            )

            textureLayers.updateThumbnail(result)
            textureLayers.selectLayer(id: textureLayerId)

        } else if let undoObject = undoObject as? UndoAdditionObject {
            let undoRepositoryUUID = undoObject.undoTextureUUID
            let undoTexture = try await undoTextureRepository
                .copyTexture(uuid: undoRepositoryUUID)

            let newTextureLayer = undoObject.textureLayer
            let newThumbnail = undoTexture.texture.makeThumbnail()

            try await textureLayers.addTexture(
                undoTexture.texture,
                newTextureUUID: newTextureLayer.id
            )

            try await textureLayers.addLayer(
                layer: .init(
                    model: newTextureLayer,
                    thumbnail: newThumbnail
                ),
                texture: undoTexture.texture,
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

            try textureLayers
                .removeTexture(undoObject.textureLayer.id)

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
            guard let result = try await textureLayers.duplicatedTexture(id: undoObject.textureLayer.id) else { return }

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
