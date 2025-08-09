//
//  Undo.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import CanvasView
import MetalKit
import SwiftUI

@MainActor
final class Undo {

    private var undoStack: UndoStack?

    private var oldAlpha: Int?

    init(undoStack: UndoStack?) {
        self.undoStack = undoStack
    }

    func addUndoAdditionObject(
        canvasState: CanvasState?,
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerItem,
        texture: MTLTexture?
    ) async {
        guard let canvasState else { return }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[previousLayerIndex].id
        )

        await undoStack?.pushUndoAdditionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoDeletionObject(
        canvasState: CanvasState?,
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerItem,
        texture: MTLTexture?
    ) async {
        guard let canvasState else { return }

        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: canvasState.layers[currentLayerIndex].id
        )

        // Create a addition undo object to cancel the deletion
        let undoObject = UndoAdditionObject(
            layerToBeAdded: redoObject.textureLayer,
            insertIndex: previousLayerIndex
        )

        await undoStack?.pushUndoDeletionObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject,
                texture: texture
            )
        )
    }

    func addUndoMoveObject(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        textureLayer: TextureLayerItem
    ) {
        let redoObject = UndoMoveObject(
            indices: indices,
            selectedLayerId: selectedLayerId,
            layer: textureLayer
        )

        let undoObject = redoObject.reversedObject

        undoStack?.pushUndoObject(
            .init(
                undoObject: undoObject,
                redoObject: redoObject
            )
        )
    }

    func addUndoAlphaObject(
        canvasState: CanvasState?,
        dragging: Bool
    ) {
        guard let canvasState else { return }

        if dragging, let alpha = canvasState.selectedLayer?.alpha {
            self.oldAlpha = alpha
        } else {
            if let oldAlpha = self.oldAlpha,
               let newAlpha = canvasState.selectedLayer?.alpha,
               let selectedLayer = canvasState.selectedLayer {

                let undoObject = UndoAlphaChangedObject(
                    layer: .init(model: selectedLayer),
                    withNewAlpha: Int(oldAlpha)
                )

                undoStack?.pushUndoObject(
                    .init(
                        undoObject: undoObject,
                        redoObject: UndoAlphaChangedObject(
                            layer: undoObject.textureLayer,
                            withNewAlpha: newAlpha
                        )
                    )
                )
            }

            self.oldAlpha = nil
        }
    }
}
