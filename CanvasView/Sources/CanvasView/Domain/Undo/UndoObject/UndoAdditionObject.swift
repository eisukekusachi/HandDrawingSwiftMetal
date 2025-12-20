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

    public let undoTextureId: UndoTextureId

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
        at index: Int
    ) {
        self.undoTextureId = UndoTextureId()
        self.textureLayer = textureLayer
        self.insertIndex = index
    }

    @MainActor
    public func applyUndo(layers: any TextureLayersProtocol, repository: TextureInMemoryRepository) async throws {
        let result = try await repository.duplicatedTexture(undoTextureId)

        try await layers.addLayer(
            layer: textureLayer,
            texture: result.texture,
            at: insertIndex
        )

        layers.requestFullCanvasUpdate()
    }
}
