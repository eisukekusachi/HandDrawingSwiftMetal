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
public final class UndoAdditionObject: UndoObject {

    public let undoTextureUUID: UUID

    /// The layer added by undo
    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    /// The insertion index for the undo-added layer
    public let insertIndex: Int

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layerToBeAdded textureLayer: TextureLayerModel,
        insertIndex: Int
    ) {
        self.undoTextureUUID = UUID()
        self.textureLayer = textureLayer
        self.insertIndex = insertIndex
    }

    /// Copies a texture from the `undoTextureRepository` to the `textureRepository` to restore a layer during an undo operation
    public func performTextureOperation(
        textureRepository: TextureRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        let result = try await undoTextureRepository
            .copyTexture(uuid: undoTextureUUID)

        try await textureRepository.addTexture(
            result.texture,
            newTextureUUID: textureLayer.id
        )
    }
}
