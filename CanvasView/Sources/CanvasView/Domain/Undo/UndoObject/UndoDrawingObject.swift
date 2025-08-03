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

    let undoTextureUUID: UUID

    let textureLayer: TextureLayerItem

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        layer: TextureLayerItem
    ) {
        self.undoTextureUUID = UUID()
        self.textureLayer = layer
    }

    /// Copies a texture from the `undoTextureRepository` to the `textureRepository` to restore a layer during an undo operation
    func performTextureOperation(
        textureRepository: TextureRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        let result = try await undoTextureRepository.copyTexture(uuid: undoTextureUUID)
        try await textureRepository.updateTexture(
            texture: result.texture,
            for: textureLayer.id
        )
    }
}
