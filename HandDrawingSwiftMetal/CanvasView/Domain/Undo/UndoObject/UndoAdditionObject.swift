//
//  UndoAdditionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import Combine
import Foundation
import MetalKit

/// An undo object for adding a texture layer
final class UndoAdditionObject: UndoObject {

    let undoTextureUUID: UUID

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
        insertIndex: Int
    ) {
        self.undoTextureUUID = UUID()
        self.textureLayer = textureLayer
        self.insertIndex = insertIndex
    }

    init(_ object: UndoDeletionObject, insertIndex: Int) {
        self.undoTextureUUID = object.undoTextureUUID
        self.textureLayer = object.textureLayer
        self.insertIndex = insertIndex
    }

    /// Copies a texture from the `undoTextureRepository` to the `textureLayerRepository` to restore a layer during an undo operation
    func performUndo(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        let result = try await undoTextureRepository
            .copyTexture(uuid: undoTextureUUID)

        try await textureLayerRepository.addTexture(
            result.texture,
            newTextureUUID: textureLayer.id
        )
    }
}
