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
    var isUndoEnabled: Bool {
        inMemoryRepository != nil
    }

    private let onRegisterUndoObjectPair: ((UndoRedoObjectPair) -> Void)?

    private let inMemoryRepository: UndoTextureInMemoryRepositoryProtocol?

    private var previousAlpha: Int?

    private let renderer: MTLRendering

    private var cancellables = Set<AnyCancellable>()

    init(
        textureLayers: TextureLayersState,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        inMemoryRepository: UndoTextureInMemoryRepositoryProtocol? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil,
        onRegisterUndoObjectPair: ((UndoRedoObjectPair) -> Void)? = nil
    ) {
        self.renderer = MTLRenderer(device: device, commandQueue: commandQueue)
        self.inMemoryRepository = inMemoryRepository ?? UndoTextureInMemoryRepository.shared
        self.onRegisterUndoObjectPair = onRegisterUndoObjectPair
        super.init(
            textureLayers: textureLayers,
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

    @discardableResult
    override func onTapInsertButton() async throws -> Bool {
        guard
            try await super.onTapInsertButton(),
            let layerId = textureLayers.selectedLayerId,
            let layerIndex = textureLayers.selectedIndex,
            let layer = textureLayers.selectedLayer
        else { return false }

        let newTexture = await textureFromDocumentsRepository(
            layerId,
            device: renderer.device
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
    override func onTapDeleteButton() async -> Bool {
        do {
            guard
                let layerId = textureLayers.selectedLayerId,
                let layerIndex = textureLayers.selectedIndex,
                let layer = textureLayers.selectedLayer,
                let texture = await textureFromDocumentsRepository(layerId, device: renderer.device),
                await super.onTapDeleteButton()
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

        } catch {
            Logger.error(error)
            return false
        }
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
            try await inMemoryRepository
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
            try await inMemoryRepository
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
