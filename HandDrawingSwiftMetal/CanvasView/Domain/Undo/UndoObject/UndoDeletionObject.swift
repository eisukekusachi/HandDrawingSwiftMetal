//
//  UndoDeletionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import Combine
import Foundation
import MetalKit

/// An undo object for removing a texture layer
final class UndoDeletionObject: UndoObject {

    /// Not used
    let undoTextureUUID: UUID = UUID()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    let selectedLayerIdAfterDeletion: UUID

    deinit {
        deinitSubject.send(self)
    }

    init(
        layerToBeDeleted textureLayer: TextureLayerModel,
        selectedLayerIdAfterDeletion layerId: UUID
    ) {
        self.textureLayer = textureLayer
        self.selectedLayerIdAfterDeletion = layerId
    }

    func updateTextureLayerRepositoryIfNeeded(
        _ textureLayerRepository: TextureLayerRepository,
        using undoTextureRepository: TextureRepository
    ) -> AnyPublisher<Void, Error> {
        let textureUUID = textureLayer.id
        return textureLayerRepository
            .removeTexture(textureUUID)
            .map { _ in return }
            .eraseToAnyPublisher()
    }

}
