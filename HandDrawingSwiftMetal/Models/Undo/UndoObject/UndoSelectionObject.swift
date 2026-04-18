//
//  UndoSelectionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/12/20.
//

import Combine
import TextureLayerView

/// An undo object for reverting layer selection
final class UndoSelectionObject: UndoObject {

    let undoTextureId: UndoTextureId? = nil

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
