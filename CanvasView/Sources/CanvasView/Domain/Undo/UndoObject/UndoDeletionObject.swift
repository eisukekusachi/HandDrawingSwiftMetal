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
public final class UndoDeletionObject: UndoObject {

    /// Not used
    public let undoTextureUUID: UUID = UUID()

    public let textureLayer: TextureLayerItem

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    public let selectedLayerIdAfterDeletion: UUID

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layerToBeDeleted textureLayer: TextureLayerItem,
        selectedLayerIdAfterDeletion layerId: UUID
    ) {
        self.textureLayer = textureLayer
        self.selectedLayerIdAfterDeletion = layerId
    }

    public func performUndo(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        try textureLayerRepository
            .removeTexture(textureLayer.id)
    }
}
