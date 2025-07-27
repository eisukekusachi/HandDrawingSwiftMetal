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
        self.textureLayer = .init(model: textureLayer, alpha: alpha)
    }

    init(
        _ object: UndoAlphaChangedObject,
        withNewAlpha newAlpha: Int
    ) {
        var textureLayer = object.textureLayer
        self.textureLayer = .init(model: textureLayer, alpha: newAlpha)
    }

    func performUndo(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        // Do nothing
    }
}
