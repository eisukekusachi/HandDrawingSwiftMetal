//
//  UndoObjectProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/19.
//

import Combine
import Foundation
import MetalKit

/// An undo object for drawing
final class UndoDrawingObject: UndoObject {

    let undoTextureId: UndoTextureId

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        from layer: TextureLayerModel
    ) {
        self.undoTextureId = UndoTextureId()
        self.textureLayer = layer
    }
}
