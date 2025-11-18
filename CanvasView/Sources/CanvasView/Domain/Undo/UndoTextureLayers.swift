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

    public var isEnabled: Bool  {
        textureLayers.isEnabled
    }

    public var isUndoEnabled: Bool {
        undoTextureRepository != nil
    }

    /// Emits `UndoRedoButtonState` when the undo stack changes
    public var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private let didUndoSubject: PassthroughSubject<UndoRedoButtonState, Never> = .init()

    /// Emits when a message needs to be sent
    public var messagePublisher: AnyPublisher<String, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    private let messageSubject: PassthroughSubject<String, Never> = .init()

    @Published private(set) var textureLayers: any TextureLayersProtocol

    private let undoManager = UndoManager()

    /// A repository that stores textures for undo operations
    private var undoTextureRepository: TextureInMemoryRepository? = nil

    private var canvasRenderer: CanvasRenderer?

    /// Holds the previous texture to support undoing drawings
    private var previousDrawingTextureForUndo: MTLTexture?

    /// Holds the previous alpha value to support undoing transparency changes
    private var previousAlphaForUndo: Int?

    private var cancellables = Set<AnyCancellable>()

    public init(
        textureLayers: any TextureLayersProtocol,
        canvasRenderer: CanvasRenderer
    ) {
        self.textureLayers = textureLayers
        self.canvasRenderer = canvasRenderer
    }

    public func setupUndoManager(
        undoCount: Int = 24
    ) {
        self.undoManager.levelsOfUndo = undoCount
        self.undoManager.groupsByEvent = false
    }

    public func setUndoTextureRepository(
        undoTextureRepository: TextureInMemoryRepository
    ) {
        self.undoTextureRepository = undoTextureRepository
    }

    public func initializeUndoTextureRepository(
        _ size: CGSize
    ) {
        guard
            let _ = undoTextureRepository,
            let device = canvasRenderer?.device
        else {
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
                    // Create a texture for use in drawing undo operations
                    previousDrawingTextureForUndo = MTLTextureCreator.makeTexture(
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
        undoManager.removeAllActions()
        undoTextureRepository?.removeAll()
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
    ) async {
        await pushUndoDrawingObject(texture: texture)
    }
}

private extension UndoTextureLayers {

    func setDrawingUndoObject(
        texture: MTLTexture?
    ) async {
        guard
            let texture,
            let previousDrawingTextureForUndo,
            let _ = undoTextureRepository
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "selectedLayer"))
            return
        }

        do {
            try await canvasRenderer?.copyTexture(
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
    ) async {
        guard
            let texture,
            let previousDrawingTextureForUndo,
            let undoTextureRepository,
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
            try await undoTextureRepository
                .addTexture(
                    previousDrawingTextureForUndo,
                    id: undoObject.undoTextureId
                )

            try await undoTextureRepository
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

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoAdditionObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) async {
        guard
            let undoTexture = undoRedoObject.texture,
            let undoTextureRepository
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "undoRedoObject.texture"))
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository
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
            let undoTexture = undoRedoObject.texture,
            let undoTextureRepository
        else {
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), "undoRedoObject.texture"))
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try await undoTextureRepository
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

    func pushUndoObject(
        _ undoRedoObject: UndoStackModel<UndoObject>
    ) {
        guard let undoTextureRepository else { return }

        let undoObject = undoRedoObject.undoObject
        let redoObject = undoRedoObject.redoObject

        undoObject.deinitSubject
            .sink(receiveValue: { result in
                // Do nothing if an error occurs, since nothing can be done
                try? undoTextureRepository.removeTexture(
                    result.undoTextureId
                )
            })
            .store(in: &cancellables)

        redoObject.deinitSubject
            .sink(receiveValue: { result in
                // Do nothing if an error occurs, since nothing can be done
                try? undoTextureRepository.removeTexture(
                    result.undoTextureId
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
        _ undoStack: UndoStackModel<UndoObject>
    ) {
        guard let _ = undoTextureRepository else { return }

        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.performUndo(undoStack.undoObject)

            // Redo Registration
            self?.pushUndoObject(undoStack.reversedObject)
        }
        undoManager.endUndoGrouping()
        didUndoSubject.send(.init(undoManager))
    }

    func performUndo(
        _ undoObject: UndoObject
    ) {
        guard let undoTextureRepository else { return }

        Task {
            do {
                try await undoObject.applyUndo(
                    layers: textureLayers,
                    repository: undoTextureRepository
                )

            } catch {
                Logger.error(error)
            }
        }
    }
}

extension UndoTextureLayers: TextureLayersProtocol {

    public func addNewLayer(at index: Int) async throws {
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

        guard
            let device = canvasRenderer?.device,
            let texture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
            else { return }

        try await addLayer(
            layer: .init(
                id: LayerId(),
                title: TimeStampFormatter.currentDate,
                alpha: 255,
                isVisible: true
            ),
            texture: texture,
            at: index
        )
    }

    public func addLayer(layer: TextureLayerModel, texture: MTLTexture?, at index: Int) async throws {
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

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
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

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
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

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
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

        textureLayers.selectLayer(id)
    }

    /// Marks the beginning of an alpha (opacity) change session (e.g. slider drag began).
    public func beginAlphaChange() {
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

        guard let _ = undoTextureRepository else { return }

        guard let alpha = textureLayers.selectedLayer?.alpha else { return }
        self.previousAlphaForUndo = alpha
    }

    /// Marks the end of an alpha (opacity) change session (e.g. slider drag ended/cancelled).
    public func endAlphaChange() {
        guard isEnabled else {
            messageSubject.send(String(localized: "Components are unavailable while drawing", bundle: .module))
            return
        }

        guard
            let _ = undoTextureRepository,
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

    public func setIsEnabled(_ isEnabled: Bool) {
        textureLayers.setIsEnabled(isEnabled)
    }

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

    public func initialize(
        configuration: ResolvedTextureLayerArrayConfiguration,
        textureRepository: (any TextureRepository)?
    ) async {
        await textureLayers.initialize(
            configuration: configuration,
            textureRepository: textureRepository
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

    public func updateThumbnail(_ id: LayerId, texture: MTLTexture) {
        textureLayers.updateThumbnail(id, texture: texture)
    }

    public func updateTitle(_ id: LayerId, title: String) {
        textureLayers.updateTitle(id, title: title)
    }

    public func updateVisibility(_ id: LayerId, isVisible: Bool) {
        textureLayers.updateVisibility(id, isVisible: isVisible)
    }

    public func updateAlpha(_ id: LayerId, alpha: Int) {
        textureLayers.updateAlpha(id, alpha: alpha)
    }

    public func updateTexture(texture: MTLTexture, for id: LayerId) async throws {
        try await textureLayers.updateTexture(texture: texture, for: id)
    }

    public func requestCanvasUpdate() {
        textureLayers.requestCanvasUpdate()
    }

    public func requestFullCanvasUpdate() {
        textureLayers.requestFullCanvasUpdate()
    }
}
