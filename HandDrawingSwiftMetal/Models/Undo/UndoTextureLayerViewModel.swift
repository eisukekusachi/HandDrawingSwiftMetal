//
//  UndoTextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/22.
//

import CanvasView
import Combine
import Foundation
import MetalKit
import TextureLayerView

final class UndoTextureLayerViewModel: TextureLayerViewModel {

    /// Is the undo feature enabled
    public var isUndoEnabled: Bool {
        inMemoryRepository != nil
    }

    private let onRegisterUndoObjectPair: ((UndoRedoObjectPair) -> Void)?

    private let inMemoryRepository: UndoTextureInMemoryRepository?

    /// Holds the previous texture to support undoing drawings
    private var previousDrawingTextureForUndo: MTLTexture?

    private var previousAlpha: Int?

    private var renderer: MTLRendering?

    private let device: MTLDevice?

    private var cancellables = Set<AnyCancellable>()

    init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        inMemoryRepository: UndoTextureInMemoryRepository? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil,
        onRegisterUndoObjectPair: ((UndoRedoObjectPair) -> Void)? = nil
    ) {
        self.device = device
        self.renderer = MTLRenderer(device: device, commandQueue: commandQueue)
        self.inMemoryRepository = inMemoryRepository ?? .shared
        self.onRegisterUndoObjectPair = onRegisterUndoObjectPair
        super.init(
            device: device,
            commandQueue: commandQueue,
            onLayersChanged: onLayersChanged
        )
        self.$isAlphaSliderDragging
            .sink { [weak self] isDragging in
                guard let `self` else { return }
                if isDragging {
                    self.previousAlpha = self.currentAlpha
                } else {
                    self.pushUndoAlphaObject(
                        item: self.textureLayers.selectedLayer
                    )
                }
            }.store(in: &cancellables)
    }

    func initializeUndoTextures(
        textureSize: CGSize
    ) {
        // Create a texture for use in drawing undo operations
        previousDrawingTextureForUndo = renderer?.makeTexture(textureSize)
    }

    @discardableResult
    override func onTapInsertButton() async throws -> Bool {
        guard
            try await super.onTapInsertButton(),
            let layerId = textureLayers.selectedLayerId,
            let layerIndex = textureLayers.selectedIndex,
            let layer = textureLayers.selectedLayer
        else { return false }

        let newTexture = try await textureFromDocumentsRepository(
            layerId,
            device: device
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: .init(item: layer)
        )
        let redoObject = UndoAdditionObject(
            layerToBeAdded: .init(item: layer),
            at: layerIndex
        )

        await pushUndoAdditionObject(
            newTexture: newTexture,
            undoRedoObject: .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )

        return true
    }

    @discardableResult
    override func onTapDeleteButton() async throws -> Bool {
        guard
            let layerId = textureLayers.selectedLayerId,
            let layerIndex = textureLayers.selectedIndex,
            let layer = textureLayers.selectedLayer,
            let texture = try await textureFromDocumentsRepository(layerId, device: device),
            try await super.onTapDeleteButton()
        else { return false }

        let undoObject = UndoAdditionObject(
            layerToBeAdded: .init(item: layer),
            at: layerIndex
        )
        // Create a deletion undo object to cancel the addition
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: .init(item: layer)
        )

        try await pushUndoDeletionObject(
            restorationTexture: texture,
            undoRedoObject: .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )

        return true
    }

    override func onTapTitleButton(_ id: LayerId, title: String) {
        guard let layer = textureLayers.layers.first(where: { $0.id == id }) else { return }
        let undoObject = UndoTitleObject(
            layer: .init(item: layer)
        )

        super.onTapTitleButton(id, title: title)

        guard let layer = textureLayers.layers.first(where: { $0.id == id }) else { return }
        let redoObject = UndoTitleObject(
            layer: .init(item: layer)
        )

        onRegisterUndoObjectPair?(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    override func onTapVisibleButton(_ id: LayerId, isVisible: Bool) {
        guard let layer = textureLayers.layers.first(where: { $0.id == id }) else { return }
        let undoObject = UndoVisibilityObject(
            layer: .init(item: layer)
        )

        super.onTapVisibleButton(id, isVisible: isVisible)

        guard let layer = textureLayers.layers.first(where: { $0.id == id }) else { return }
        let redoObject = UndoVisibilityObject(
            layer: .init(item: layer)
        )

        onRegisterUndoObjectPair?(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    override func onTapCell(_ id: UUID) {
        guard let layer = textureLayers.selectedLayer else { return }
        let undoObject = UndoSelectionObject(
            layer: .init(item: layer)
        )

        super.onTapCell(id)

        guard let layer = textureLayers.selectedLayer else { return }
        let redoObject = UndoSelectionObject(
            layer: .init(item: layer)
        )

        onRegisterUndoObjectPair?(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    override func onMoveLayer(source: IndexSet, destination: Int) {
        guard let layer = textureLayers.selectedLayer else { return }

        super.onMoveLayer(source: source, destination: destination)

        let redoObject = UndoMoveObject(
            indices: .init(sourceIndexSet: source, destinationIndex: destination),
            selectedLayerId: layer.id,
            layer: .init(item: layer)
        )

        onRegisterUndoObjectPair?(
            .init(
                undoObject: redoObject.reversedObject,
                redoObject: redoObject
            )
        )
    }

    func pushUndoAlphaObject(
        item: TextureLayerItem?
    ) {
        guard
            let item,
            let previousAlpha
        else { return }

        let undoObject = UndoAlphaObject(
            layer: .init(item: item),
            alpha: previousAlpha
        )
        let redoObject = UndoAlphaObject(
            layer: .init(item: item),
            alpha: item.alpha
        )

        onRegisterUndoObjectPair?(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    func pushUndoDrawingObject(
        texture: MTLTexture?
    ) async throws {
        guard
            let renderer,
            let inMemoryRepository
        else { return }

        guard
            let selectedLayer = textureLayers.selectedLayer
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "selectedLayer"))
            return
        }
        guard
            let undoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: previousDrawingTextureForUndo,
                renderer: renderer
            )
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "undoTexture"))
            return
        }
        guard
            let redoTexture = try await MTLTextureCreator.duplicateTexture(
                texture: texture,
                renderer: renderer
            )
        else {
            Logger.error(String(format: String(localized: "Unable to find %@"), "redoTexture"))
            return
        }

        let undoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer)
        )
        let redoObject = UndoDrawingObject(
            layer: .init(item: selectedLayer)
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

            onRegisterUndoObjectPair?(
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
}

extension UndoTextureLayerViewModel {

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

            onRegisterUndoObjectPair?(
                undoRedoObject
            )

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func pushUndoDeletionObject(
        restorationTexture: MTLTexture,
        undoRedoObject: UndoRedoObjectPair
    ) async throws {
        guard
            let undoTextureId = undoRedoObject.undoObject.undoTextureId,
            let inMemoryRepository
        else {
            return
        }

        do {
            // Add a texture to the UndoTextureRepository for restoration
            try inMemoryRepository
                .addTexture(
                    newTexture: restorationTexture,
                    id: undoTextureId
                )

            onRegisterUndoObjectPair?(
                undoRedoObject
            )
        } catch {
            // No action on error
            Logger.error(error)
        }
    }
}
