//
//  UndoHandler.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import CanvasView
import MetalKit
import SwiftUI

@MainActor
public final class UndoHandler {

    private var textureLayers: TextureLayers?
    private var undoStack: UndoStack?

    private var oldAlpha: Int?

    init(
        textureLayers: TextureLayers?,
        undoStack: UndoStack?
    ) {
        self.textureLayers = textureLayers
        self.undoStack = undoStack
    }

    func addUndoAdditionObject(
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) async {
        guard let textureLayers else { return }

        let redoObject = UndoAdditionObject(
            layerToBeAdded: layer,
            insertIndex: currentLayerIndex
        )

        // Create a deletion undo object to cancel the addition
        let undoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: textureLayers.layers[previousLayerIndex].id
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
        previousLayerIndex: Int,
        currentLayerIndex: Int,
        layer: TextureLayerModel,
        texture: MTLTexture?
    ) async {
        guard let textureLayers else { return }

        // Add an undo object to the undo stack
        let redoObject = UndoDeletionObject(
            layerToBeDeleted: layer,
            selectedLayerIdAfterDeletion: textureLayers.layers[currentLayerIndex].id
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
        textureLayer: TextureLayerModel
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
        dragging: Bool
    ) {
        guard let textureLayers else { return }

        if dragging, let alpha = textureLayers.selectedLayer?.alpha {
            self.oldAlpha = alpha
        } else {
            if let oldAlpha = self.oldAlpha,
               let newAlpha = textureLayers.selectedLayer?.alpha,
               let selectedLayer = textureLayers.selectedLayer {

                let undoObject = UndoAlphaChangedObject(
                    layer: .init(item: selectedLayer),
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
