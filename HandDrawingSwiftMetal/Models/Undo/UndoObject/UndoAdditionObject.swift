//
//  UndoAdditionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import Combine
import TextureLayerView

/// An undo object for adding a texture layer
final class UndoAdditionObject: UndoObject {

    let undoTextureId: UndoTextureId? = UndoTextureId()

    /// The layer added by undo
    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    /// The insertion index for the undo-added layer
    let insertIndex: Int

    deinit {
        deinitSubject.send(self)
    }

    init(
        layerToBeAdded textureLayer: TextureLayerModel,
        at index: Int
    ) {
        self.textureLayer = textureLayer
        self.insertIndex = index
    }
}
