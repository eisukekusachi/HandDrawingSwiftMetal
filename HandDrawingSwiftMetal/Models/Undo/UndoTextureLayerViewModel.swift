//
//  UndoTextureLayerViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/22.
//

import CanvasView
import Combine
import MetalKit
import TextureLayerView

final class UndoTextureLayerViewModel: TextureLayerViewModel {

    /// Is the undo feature enabled
    var isUndoEnabled: Bool {
        inMemoryRepository != nil
    }

    private let onRegisterUndo: ((UndoRedoObjectPair) -> Void)?

    private let inMemoryRepository: UndoTextureInMemoryRepositoryProtocol?

    private let device: MTLDevice

    private var previousAlpha: Int?

    private var cancellables = Set<AnyCancellable>()

    init(
        textureLayers: TextureLayersState,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        inMemoryRepository: UndoTextureInMemoryRepositoryProtocol? = nil,
        onLayersChanged: ((TextureLayerEvent) -> Void)? = nil,
        onRegisterUndo: ((UndoRedoObjectPair) -> Void)? = nil
    ) {
        self.device = device
        self.inMemoryRepository = inMemoryRepository ?? UndoTextureInMemoryRepository.shared
        self.onRegisterUndo = onRegisterUndo
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
                    guard
                        let item = self.textureLayers.selectedLayer,
                        let previousAlpha = self.previousAlpha
                    else { return }
                    self.onRegisterUndo?(
                        .init(
                            undoObject: UndoAlphaObject(
                                layer: .init(item: item),
                                alpha: previousAlpha
                            ),
                            redoObject: UndoAlphaObject(
                                layer: .init(item: item),
                                alpha: item.alpha
                            )
                        )
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

        let newTexture = try await textureFromDocumentsRepository(
            layerId,
            device: device
        )

        await registerAdditionUndo(
            newTexture: newTexture,
            // Create a deletion undo object to cancel the addition
            undoRedoObject: .init(
                undoObject: UndoDeletionObject(
                    layerToBeDeleted: .init(item: layer)
                ),
                redoObject: UndoAdditionObject(
                    layerToBeAdded: .init(item: layer),
                    at: layerIndex
                )
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
                let layer = textureLayers.selectedLayer
            else { return false }

            let texture = try await textureFromDocumentsRepository(layerId, device: device)

            await super.onTapDeleteButton()

            try await registerDeletionUndo(
                restorationTexture: texture,
                undoRedoObject: .init(
                    undoObject: UndoAdditionObject(
                        layerToBeAdded: .init(item: layer),
                        at: layerIndex
                    ),
                    // Create a deletion undo object to cancel the addition
                    redoObject: UndoDeletionObject(
                        layerToBeDeleted: .init(item: layer)
                    )
                )
            )
            return true

        } catch {
            Logger.error(error)
            return false
        }
    }

    override func onTapTitleButton(_ id: LayerId, title: String) {
        guard let undoLayer = textureLayers.layers.first(where: { $0.id == id }) else { return }

        super.onTapTitleButton(id, title: title)

        guard let redoLayer = textureLayers.layers.first(where: { $0.id == id }) else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoTitleObject(
                    layer: .init(item: undoLayer)
                ),
                redoObject: UndoTitleObject(
                    layer: .init(item: redoLayer)
                )
            )
        )
    }

    override func onTapVisibleButton(_ id: LayerId, isVisible: Bool) {
        guard let undoLayer = textureLayers.layers.first(where: { $0.id == id }) else { return }

        super.onTapVisibleButton(id, isVisible: isVisible)

        guard let redoLayer = textureLayers.layers.first(where: { $0.id == id }) else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoVisibilityObject(
                    layer: .init(item: undoLayer)
                ),
                redoObject: UndoVisibilityObject(
                    layer: .init(item: redoLayer)
                )
            )
        )
    }

    override func onTapCell(_ id: UUID) {
        guard let undoLayer = textureLayers.selectedLayer else { return }

        super.onTapCell(id)

        guard let redoLayer = textureLayers.selectedLayer else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoSelectionObject(
                    layer: .init(item: undoLayer)
                ),
                redoObject: UndoSelectionObject(
                    layer: .init(item: redoLayer)
                )
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

        onRegisterUndo?(
            .init(
                undoObject: redoObject.reversedObject,
                redoObject: redoObject
            )
        )
    }
}

private extension UndoTextureLayerViewModel {

    func registerAdditionUndo(
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

            onRegisterUndo?(
                undoRedoObject
            )

        } catch {
            // No action on error
            Logger.error(error)
        }
    }

    func registerDeletionUndo(
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

            onRegisterUndo?(
                undoRedoObject
            )
        } catch {
            // No action on error
            Logger.error(error)
        }
    }
}
