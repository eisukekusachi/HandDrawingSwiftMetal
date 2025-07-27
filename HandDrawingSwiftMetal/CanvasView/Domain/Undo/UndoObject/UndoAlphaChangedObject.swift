//
//  UndoAlphaChangedObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/28.
//

import Combine
import Foundation
import MetalKit

/// An undo object for updating a texture layer
final class UndoAlphaChangedObject: UndoObject {

    /// Not used
    let undoTextureUUID: UUID = UUID()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        alpha: Int,
        textureLayer: TextureLayerModel
    ) {
        var textureLayer = textureLayer
        textureLayer.alpha = alpha

        self.textureLayer = textureLayer
    }

    init(
        _ object: UndoAlphaChangedObject,
        withNewAlpha newAlpha: Int
    ) {
        var textureLayer = object.textureLayer
        textureLayer.alpha = newAlpha

        self.textureLayer = textureLayer
    }

    func performUndo(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        // Do nothing
    }
}
