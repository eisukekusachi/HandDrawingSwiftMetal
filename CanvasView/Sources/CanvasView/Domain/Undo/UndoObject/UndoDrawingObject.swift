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

    let undoTextureId: UndoTextureId? = UndoTextureId()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    private let renderer: MTLRendering?

    deinit {
        deinitSubject.send(self)
    }

    init(
        layer: TextureLayerModel,
        renderer: MTLRendering
    ) {
        self.textureLayer = layer
        self.renderer = renderer
    }

    @MainActor
    public func applyUndo(layers: any TextureLayersProtocol, repository: TextureInMemoryRepository) async throws {
        guard
            let renderer,
            let undoTextureId,
            let newTexture = try await MTLTextureCreator.duplicateTexture(
                texture: repository.texture(id: undoTextureId),
                renderer: renderer
            )
        else { return }

        let textureLayerId = textureLayer.id

        try await layers.updateTexture(texture: newTexture, for: textureLayerId)
        layers.selectLayer(textureLayerId)
        layers.updateThumbnail(textureLayerId, texture: newTexture)
        layers.requestCanvasDrawingUpdate(newTexture)
    }
}
