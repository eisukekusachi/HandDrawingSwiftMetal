//
//  UndoDeletionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import Combine
import TextureLayerView

/// An undo object for removing a texture layer
final class UndoDeletionObject: UndoObject {

    /// Not used
    let undoTextureId: UndoTextureId? = UndoTextureId()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        layerToBeDeleted textureLayer: TextureLayerModel
    ) {
        self.textureLayer = textureLayer
    }
}
