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

    /// Copies a texture from `UndoTextureRepository` and add it to `TextureLayerRepository`
    func updateTextureLayerRepositoryIfNeeded(
        _ textureLayerRepository: TextureLayerRepository,
        using undoTextureRepository: TextureRepository
    ) -> AnyPublisher<Void, Error> {
        let textureUUID = textureLayer.id
        return undoTextureRepository
            .copyTexture(uuid: undoTextureUUID)
            .flatMap { result in
                textureLayerRepository.addTexture(
                    result.texture,
                    newTextureUUID: textureUUID
                )
            }
            .map { _ in return }
            .eraseToAnyPublisher()
    }

}
