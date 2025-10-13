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

    @Published private var textureLayers: TextureLayers

    private let undoManager = UndoManager()

    private var undoTextureRepository: TextureInMemoryRepository? = nil

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject: PassthroughSubject<UndoRedoButtonState, Never> = .init()

    /// An undo object captured at the start of the stroke, shown when undo is triggered.
    private var drawingUndoObject: UndoObject?

    private var undoDrawingTexture: MTLTexture?

    private var oldAlpha: Int?

    private var canvasRenderer: CanvasRenderer?

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: TextureLayers
    ) {
        self.textureLayers = textureLayers
    }

    public func initialize(
        undoCount: Int = 64,
        undoTextureRepository: TextureInMemoryRepository,
    ) {
        self.undoTextureRepository = undoTextureRepository

        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    public func initializeStorage(
        _ size: CGSize,
        canvasRenderer: CanvasRenderer
    ) {
        self.canvasRenderer = canvasRenderer

        guard let device = canvasRenderer.device else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "device"))
            return
        }

        resetUndo()

        Task {
            do {
                if let resolvedTextureLayersConfiguration = try await undoTextureRepository?.initializeStorage(
                    configuration: .init(textureSize: size),
                    fallbackTextureSize: size
                ) {
                    undoDrawingTexture = MTLTextureCreator.makeTexture(
                        width: Int(resolvedTextureLayersConfiguration.textureSize.width),
                        height: Int(resolvedTextureLayersConfiguration.textureSize.height),
                        with: device
                    )
                }
            } catch {
                Logger.error(error)
            }
        }
    }

    public func undo() {
        undoManager.undo()
        didUndoSubject.send(.init(undoManager))
    }
    public func redo() {
        undoManager.redo()
        didUndoSubject.send(.init(undoManager))
    }
    public func resetUndo() {
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

    public var selectedLayerIdPublisher: AnyPublisher<LayerId?, Never> {
        textureLayers.selectedLayerIdPublisher
    }

    public var textureSizePublisher: AnyPublisher<CGSize, Never> {
        textureLayers.textureSizePublisher
    }

    public var alphaPublisher: AnyPublisher<Int, Never> {
        textureLayers.alphaPublisher
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

    public func layer(_ id: LayerId) -> TextureLayerItem? {
        textureLayers.layer(id)
    }

    public func selectLayer(_ id: LayerId) {
        textureLayers.selectLayer(id)
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        textureLayers.updateLayer(layer)
    }

    public func updateThumbnail(_ id: LayerId, texture: MTLTexture) {
        textureLayers.updateThumbnail(id, texture: texture)
    }

    public func updateTitle(_ id: LayerId, title: String) {
        textureLayers.updateTitle(id, title: title)
    }

    public func updateVisibility(_ id: LayerId, isVisible: Bool) {
        textureLayers.updateVisibility(id, isVisible: isVisible)
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }

    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture? {
        try await textureLayers.duplicatedTexture(id)
    }

    public func updateTexture(texture: MTLTexture?, for id: LayerId) async throws {
        try await textureLayers.updateTexture(texture: texture, for: id)
    }
}

extension UndoTextureLayers {
    public func addNewLayer(at index: Int) async throws {
        guard
            let device = canvasRenderer?.device,
            let texture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
            else { return }

        let layer: TextureLayerModel = .init(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )

        try await addLayer(layer: layer, texture: texture, at: index)
    }

    public func addLayer(layer: TextureLayerModel, texture: MTLTexture?, at index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            at: index
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
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

    public func updateAlpha(_ id: LayerId, alpha: Int) {
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
    func setDrawingUndoObject(
        texture: MTLTexture?
    ) async {
        guard
            let texture,
            let undoDrawingTexture
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        do {
            try await canvasRenderer?.copyTexture(
                srcTexture: texture,
                dstTexture: undoDrawingTexture,
            )
        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDrawingObject(
        texture: MTLTexture?
    ) async {
        guard
            let texture,
            let undoDrawingTexture,
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }
        let undoObject = UndoDrawingObject(
            from: .init(item: selectedLayer)
        )

        let redoObject = UndoDrawingObject(
            from: .init(item: selectedLayer)
        )

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    undoDrawingTexture,
                    id: undoObject.undoTextureId
                )

            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository?
                .addTexture(
                    texture,
                    id: redoObject.undoTextureId
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
                    id: undoRedoObject.redoObject.undoTextureId
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
                    id: undoRedoObject.undoObject.undoTextureId
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
                // Do nothing if an error occurs, since nothing can be done
                try? self?.undoTextureRepository?.removeTexture(
                    result.undoTextureId
                )
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                // Do nothing if an error occurs, since nothing can be done
                try? self?.undoTextureRepository?.removeTexture(
                    result.undoTextureId
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
            let result = try await undoTextureRepository.duplicatedTexture(undoObject.undoTextureId)

            let textureLayerId = undoObject.textureLayer.id

            try await textureLayers.updateTexture(
                texture: result.texture,
                for: textureLayerId
            )

            // Drawing may occur on a different layer, so explicitly select the layer to use
            textureLayers.selectLayer(textureLayerId)

            textureLayers.updateThumbnail(textureLayerId, texture: result.texture)

            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoAdditionObject {
            let result = try await undoTextureRepository.duplicatedTexture(undoObject.undoTextureId)

            try await textureLayers.addLayer(
                layer: undoObject.textureLayer,
                texture: result.texture,
                at: undoObject.insertIndex
            )

            textureLayers.requestFullCanvasUpdate()

        } else if let undoObject = undoObject as? UndoDeletionObject {
            guard
                let index = textureLayers.index(for: undoObject.textureLayer.id)
            else {
                let message = "id: \(undoObject.textureLayer.id.uuidString)"
                Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), message))
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
            textureLayers.updateAlpha(
                undoObject.textureLayer.id,
                alpha: undoObject.textureLayer.alpha
            )

            textureLayers.requestFullCanvasUpdate()
        }
    }
}
