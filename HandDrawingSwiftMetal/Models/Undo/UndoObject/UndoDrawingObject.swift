//
//  UndoObjectProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/19.
//

import Combine
import TextureLayerView

/// An undo object for drawing
final class UndoDrawingObject: UndoObject {

    let undoTextureId: UndoTextureId? = UndoTextureId()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        layer: TextureLayerModel
    ) {
        self.textureLayer = layer
    }
}
