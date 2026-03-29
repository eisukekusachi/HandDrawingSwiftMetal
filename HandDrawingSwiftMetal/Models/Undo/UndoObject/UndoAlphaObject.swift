//
//  UndoAlphaObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/28.
//

import Combine
import TextureLayerView

/// An undo object for updating a texture layer
final class UndoAlphaObject: UndoObject {

    /// Not used
    let undoTextureId: UndoTextureId? = UndoTextureId()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        layer: TextureLayerModel,
        alpha: Int
    ) {
        self.textureLayer = .init(
            id: layer.id,
            title: layer.title,
            alpha: alpha,
            isVisible: layer.isVisible
        )
    }
}
