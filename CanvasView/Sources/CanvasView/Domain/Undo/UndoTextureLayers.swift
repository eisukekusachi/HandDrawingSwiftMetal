//
//  UndoTextureLayers.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/23.
//

import Combine
import UIKit

/// A class that manages texture layers with undo functionality
@MainActor
public final class UndoTextureLayers: ObservableObject {

    @Published private(set) var textureLayers: any TextureLayersProtocol

    /// Is the undo feature enabled
    public var isUndoEnabled: Bool {
        inMemoryRepository != nil
    }

    /// Emits `UndoRedoButtonState` when the undo stack changes
    public var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject: PassthroughSubject<UndoRedoButtonState, Never> = .init()

    private let undoManager = UndoManager()

    /// A repository that stores textures for undo operations.
    /// The textures are stored and managed in memory to avoid blocking the main thread.
    private(set) var inMemoryRepository: UndoTextureInMemoryRepository? = nil

    private var renderer: MTLRendering

    /// Holds the previous texture to support undoing drawings
    private var previousDrawingTextureForUndo: MTLTexture?

    /// Holds the previous alpha value to support undoing transparency changes
    private var previousAlphaForUndo: Int?

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: any TextureLayersProtocol,
        renderer: MTLRendering
    ) {
        self.textureLayers = textureLayers
        self.renderer = renderer
    }

    public func setupUndoManager(
        undoCount: Int = 24
    ) {
        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    public func setUndoTextureRepository(
        repository: UndoTextureInMemoryRepository
    ) {
        self.inMemoryRepository = repository
    }

    public func initializeUndoTextures(
        textureSize: CGSize
    ) {
        // Create a texture for use in drawing undo operations
        previousDrawingTextureForUndo = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
    }
}

public extension UndoTextureLayers {

    func undo() {
        undoManager.undo()
        didUndoSubject.send(.init(undoManager))
    }
    func redo() {
        undoManager.redo()
        didUndoSubject.send(.init(undoManager))
    }
    func resetUndo() {
        guard let inMemoryRepository else { return }

        inMemoryRepository.removeAll()
        undoManager.removeAllActions()
        didUndoSubject.send(.init(undoManager))
        cancellables = Set<AnyCancellable>()
    }

    func setUndoDrawing(
        texture: MTLTexture?
    ) async {
        await setDrawingUndoObject(texture: texture)
    }
    func pushUndoDrawingObjectToUndoStack(
        texture: MTLTexture?
    ) async throws {
        try await pushUndoDrawingObject(texture: texture)
    }
}

private extension UndoTextureLayers {

    func setDrawingUndoObject(
        texture: MTLTexture?
    ) async {
        guard
            let texture,
            let previousDrawingTextureForUndo
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "previousDrawingTextureForUndo"))
            return
        }

        do {
            try await renderer.copyTexture(
                srcTexture: texture,
                dstTexture: previousDrawingTextureForUndo,
            )
        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDrawingObject(
        texture: MTLTexture?
    ) async throws {
        guard
            let inMemoryRepository,
            let selectedLayer = textureLayers.selectedLayer,
            let undoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: previousDrawingTextureForUndo,
                renderer: renderer
            ),
            let redoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: texture,
                renderer: renderer
            )
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "textures"))
            return
        }
        let undoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer),
            renderer: renderer
        )

        let redoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer),
            renderer: renderer
        )

        guard
            let undoTextureId = undoObject.undoTextureId,
            let redoTextureId = redoObject.undoTextureId
        else { return }

        do {
            try inMemoryRepository
                .addTexture(
                    newTexture: undoTexture,
                    id: undoTextureId
                )

            try inMemoryRepository
                .addTexture(
                    newTexture: redoTexture,
                    id: redoTextureId
                )

            pushUndoObject(
                .init(
                    undoObject: undoObject,
                    redoObject: redoObject
                )
            )

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoAdditionObject(
        newTexture: MTLTexture?,
        undoRedoObject: UndoRedoObjectPair
    ) async {
        guard
            let newTexture,
            let undoTextureId = undoRedoObject.redoObject.undoTextureId,
            let inMemoryRepository
        else {
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try inMemoryRepository
                .addTexture(
                    newTexture: newTexture,
                    id: undoTextureId
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDeletionObject(
        restorationNewTexture: MTLTexture,
        undoRedoObject: UndoRedoObjectPair
    ) async throws {
        guard
            let undoTextureId = undoRedoObject.undoObject.undoTextureId,
            let inMemoryRepository
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "undoRedoObject.texture"))
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try inMemoryRepository
                .addTexture(
                    newTexture: restorationNewTexture,
                    id: undoTextureId
                )

            pushUndoObject(undoRedoObject)

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoObject(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        guard let inMemoryRepository else { return }

        let undoObject = undoRedoObject.undoObject
        let redoObject = undoRedoObject.redoObject

        undoObject.deinitSubject
            .sink(receiveValue: { result in
                guard let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? inMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { result in
                guard let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? inMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        registerUndo(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }
}

private extension UndoTextureLayers {

    func registerUndo(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.performUndo(undoRedoObject.undoObject)

            // Redo Registration
            self?.pushUndoObject(undoRedoObject.reversed())
        }
        undoManager.endUndoGrouping()
        didUndoSubject.send(.init(undoManager))
    }

    func performUndo(
        _ undoObject: UndoObject
    ) {
        guard let inMemoryRepository else { return }

        Task {
            do {
                try await undoObject.applyUndo(
                    layers: textureLayers,
                    repository: inMemoryRepository
                )

            } catch {
                Logger.error(error)
            }
        }
    }
}

extension UndoTextureLayers: TextureLayersProtocol {

    public func addNewLayer(at index: Int) async throws {
        guard
            let newTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: renderer.device
            )
            else { return }

        try await addLayer(
            layer: .init(
                id: LayerId(),
                title: TimeStampFormatter.currentDate,
                alpha: 255,
                isVisible: true
            ),
            newTexture: newTexture,
            at: index
        )
    }

    public func addLayer(layer: TextureLayerModel, newTexture: MTLTexture?, at index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            at: index,
            renderer: renderer
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: selectedLayer.id
        )

        try await textureLayers.addLayer(layer: layer, newTexture: newTexture, at: index)

        let undoNewTexture = try await MTLTextureCreator.duplicateTexture(
            texture: newTexture,
            renderer: renderer
        )

        await pushUndoAdditionObject(
            newTexture: undoNewTexture,
            undoRedoObject: .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    public func removeLayer(layerIndexToDelete index: Int) async throws {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let newTexture = try await textureLayers.duplicatedTexture(selectedLayer.id)?.texture
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        let selectedLayerModel: TextureLayerModel = .init(item: selectedLayer)

        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: selectedLayerModel,
            selectedLayerIdAfterDeletion: selectedLayer.id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: selectedLayerModel,
            at: index,
            renderer: renderer
        )

        try await textureLayers.removeLayer(layerIndexToDelete: index)

        try await pushUndoDeletionObject(
            restorationNewTexture: newTexture,
            undoRedoObject: .init(
                undoObject: undoObject,
                redoObject: redoObject
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

    public func selectLayer(_ id: LayerId) {
        guard let undoSelectdLayer = textureLayers.selectedLayer else { return }
        let undoObject = UndoSelectionObject(
            layer: .init(item: undoSelectdLayer)
        )

        textureLayers.selectLayer(id)

        guard let redoSelectdLayer = textureLayers.selectedLayer else { return }
        let redoObject = UndoSelectionObject(
            layer: .init(item: redoSelectdLayer)
        )

        pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        guard let _ = inMemoryRepository else { return }

        guard let alpha = textureLayers.selectedLayer?.alpha else { return }
        self.previousAlphaForUndo = alpha
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        guard
            let _ = inMemoryRepository,
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }
        guard
            let oldAlpha = self.previousAlphaForUndo,
            oldAlpha != selectedLayer.alpha
        else { return }

        let undoObject = UndoAlphaChangedObject(
            layer: .init(item: selectedLayer),
            withNewAlpha: Int(oldAlpha)
        )
        let redoObject = UndoAlphaChangedObject(
            layer: .init(item: selectedLayer),
            withNewAlpha: selectedLayer.alpha
        )

        pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )

        self.previousAlphaForUndo = nil
    }

    public func updateVisibility(_ id: LayerId, isVisible: Bool) {
        guard
            let undoSelectdLayer = textureLayers.layer(id)
        else { return }

        textureLayers.updateVisibility(id, isVisible: isVisible)

        pushUndoObject(
            .init(
                undoObject: UndoVisibilityObject(
                    layer: .init(
                        id: undoSelectdLayer.id,
                        title: undoSelectdLayer.title,
                        alpha: undoSelectdLayer.alpha,
                        isVisible: undoSelectdLayer.isVisible
                    )
                ),
                redoObject: UndoVisibilityObject(
                    layer: .init(
                        id: undoSelectdLayer.id,
                        title: undoSelectdLayer.title,
                        alpha: undoSelectdLayer.alpha,
                        isVisible: isVisible
                    )
                )
            )
        )
    }

    public var canvasUpdateRequestedPublisher: AnyPublisher<Void, Never> {
        textureLayers.canvasUpdateRequestedPublisher
    }

    public var canvasDrawingUpdateRequested: AnyPublisher<RealtimeDrawingTexture, Never> {
        textureLayers.canvasDrawingUpdateRequested
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

    public var alphaPublisher: AnyPublisher<Int, Never> {
        textureLayers.alphaPublisher
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

    public func setup(
        repository: TextureLayersDocumentsRepositoryProtocol?
    ) {
        textureLayers.setup(
            repository: repository
        )
    }

    public func updateSkippingThumbnail(
        textureLayersState: TextureLayersState
    ) {
        textureLayers.updateSkippingThumbnail(
            textureLayersState: textureLayersState
        )
    }

    public func index(for id: LayerId) -> Int? {
        textureLayers.index(for: id)
    }

    public func duplicatedTexture(_ id: LayerId) async throws -> IdentifiedTexture? {
        try await textureLayers.duplicatedTexture(id)
    }

    public func layer(_ id: LayerId) -> TextureLayerItem? {
        textureLayers.layer(id)
    }

    public func updateLayer(_ layer: TextureLayerItem) {
        textureLayers.updateLayer(layer)
    }

    public func updateThumbnail(_ id: LayerId) async throws {
        try await textureLayers.updateThumbnail(id)
    }

    public func updateThumbnail(_ id: LayerId, texture: MTLTexture) {
        textureLayers.updateThumbnail(id, texture: texture)
    }

    public func updateTitle(_ id: LayerId, title: String) {
        textureLayers.updateTitle(id, title: title)
    }

    public func updateAlpha(_ id: LayerId, alpha: Int) {
        textureLayers.updateAlpha(id, alpha: alpha)
    }

    public func writeTextureToDisk(texture: MTLTexture, for id: LayerId) async throws {
        try await textureLayers.writeTextureToDisk(texture: texture, for: id)
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestCanvasDrawingUpdate(_ texture: RealtimeDrawingTexture) {
        textureLayers.requestCanvasDrawingUpdate(texture)
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }
}
