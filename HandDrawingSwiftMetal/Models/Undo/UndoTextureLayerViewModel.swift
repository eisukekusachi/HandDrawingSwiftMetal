//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
import MetalKit
import TextureLayerView

@MainActor
final class UndoTextureLayerRegistrar {

    private let onRegisterUndo: ((UndoRedoObjectPair) -> Void)?

    private let showError: (Error) -> Void

    private let textureRepository: TextureLayersDocumentsRepositoryProtocol

    private let inMemoryRepository: UndoTextureInMemoryRepositoryProtocol?

    private let device: MTLDevice

    private var previousAlpha: Int?

    init(
        device: MTLDevice,
        textureRepository: TextureLayersDocumentsRepositoryProtocol,
        inMemoryRepository: UndoTextureInMemoryRepositoryProtocol? = nil,
        onRegisterUndo: ((UndoRedoObjectPair) -> Void)? = nil,
        showError: @escaping (Error) -> Void = { _ in }
    ) {
        self.device = device
        self.textureRepository = textureRepository
        self.inMemoryRepository = inMemoryRepository ?? UndoTextureInMemoryRepository.shared
        self.onRegisterUndo = onRegisterUndo
        self.showError = showError
    }

    func didAddLayer(in state: TextureLayersState) async {
        guard
            let layerId = state.selectedLayerId,
            let layerIndex = state.selectedLayerIndex,
            let layer = state.selectedLayer
        else { return }

        let newTexture: MTLTexture
        do {
            newTexture = try await textureRepository.duplicatedTexture(
                layerId,
                textureSize: state.textureSize,
                device: device
            )
        } catch {
            showError(error)
            return
        }

        await registerAdditionUndo(
            newTexture: newTexture,
            undoRedoObject: .init(
                undoObject: UndoDeletionObject(
                    layerToBeDeleted: layer
                ),
                redoObject: UndoAdditionObject(
                    layerToBeAdded: layer,
                    at: layerIndex
                )
            )
        )
    }

    func removeLayer(
        in state: TextureLayersState,
        _ perform: () async throws -> Bool
    ) async throws -> Bool {
        guard
            let layerId = state.selectedLayerId,
            let layerIndex = state.selectedLayerIndex,
            let layer = state.selectedLayer
        else { return false }

        let texture: MTLTexture
        do {
            texture = try await textureRepository.duplicatedTexture(
                layerId,
                textureSize: state.textureSize,
                device: device
            )
        } catch {
            showError(error)
            return false
        }

        guard try await perform() else { return false }

        try await registerDeletionUndo(
            restorationTexture: texture,
            undoRedoObject: .init(
                undoObject: UndoAdditionObject(
                    layerToBeAdded: layer,
                    at: layerIndex
                ),
                redoObject: UndoDeletionObject(
                    layerToBeDeleted: layer
                )
            )
        )
        return true
    }

    func renameLayer(
        in state: TextureLayersState,
        id: LayerId,
        title: String,
        perform: () throws -> Void
    ) rethrows {
        guard let undoLayer = state.layer(id) else { return }

        try perform()

        guard let redoLayer = state.layer(id) else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoTitleObject(
                    layer: undoLayer
                ),
                redoObject: UndoTitleObject(
                    layer: redoLayer
                )
            )
        )
    }

    func changeVisibility(
        in state: TextureLayersState,
        id: LayerId,
        isVisible: Bool,
        perform: () throws -> Void
    ) rethrows {
        guard let undoLayer = state.layer(id) else { return }

        try perform()

        guard let redoLayer = state.layer(id) else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoVisibilityObject(
                    layer: undoLayer
                ),
                redoObject: UndoVisibilityObject(
                    layer: redoLayer
                )
            )
        )
    }

    func selectLayer(
        in state: TextureLayersState,
        id: LayerId,
        perform: () throws -> Void
    ) rethrows {
        guard let undoLayer = state.selectedLayer else { return }

        try perform()

        guard let redoLayer = state.selectedLayer else { return }

        onRegisterUndo?(
            .init(
                undoObject: UndoSelectionObject(
                    layer: undoLayer
                ),
                redoObject: UndoSelectionObject(
                    layer: redoLayer
                )
            )
        )
    }

    func moveLayer(
        in state: TextureLayersState,
        source: IndexSet,
        destination: Int,
        perform: () throws -> Void
    ) rethrows {
        guard let layer = state.selectedLayer else { return }

        try perform()

        let redoObject = UndoMoveObject(
            indices: .init(sourceIndexSet: source, destinationIndex: destination),
            selectedLayerId: layer.id,
            layer: layer
        )

        onRegisterUndo?(
            .init(
                undoObject: redoObject.reversedObject,
                redoObject: redoObject
            )
        )
    }

    func alphaSliderDraggingChanged(
        in state: TextureLayersState,
        _ isDragging: Bool
    ) {
        if isDragging {
            previousAlpha = state.selectedLayer?.alpha
        } else {
            guard
                let item = state.selectedLayer,
                let previousAlpha
            else { return }
            onRegisterUndo?(
                .init(
                    undoObject: UndoAlphaObject(
                        layer: item,
                        alpha: previousAlpha
                    ),
                    redoObject: UndoAlphaObject(
                        layer: item,
                        alpha: item.alpha
                    )
                )
            )
        }
    }
}

private extension UndoTextureLayerRegistrar {

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
            try await inMemoryRepository
                .addTexture(
                    newTexture: newTexture,
                    id: undoTextureId
                )

            onRegisterUndo?(
                undoRedoObject
            )

        } catch {
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
            try await inMemoryRepository
                .addTexture(
                    newTexture: restorationTexture,
                    id: undoTextureId
                )

            onRegisterUndo?(
                undoRedoObject
            )
        } catch {
            Logger.error(error)
        }
    }
}
