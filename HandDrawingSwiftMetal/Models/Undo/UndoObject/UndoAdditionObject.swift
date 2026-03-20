//
//  UndoAdditionObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import CanvasView
import Combine
import Foundation
import MetalKit
import TextureLayerView

/// An undo object for adding a texture layer
public final class UndoAdditionObject: UndoObject {

    public let undoTextureId: UndoTextureId? = UndoTextureId()

    /// The layer added by undo
    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    /// The insertion index for the undo-added layer
    public let insertIndex: Int

    private let renderer: MTLRendering

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layerToBeAdded textureLayer: TextureLayerModel,
        at index: Int,
        renderer: MTLRendering
    ) {
        self.textureLayer = textureLayer
        self.insertIndex = index
        self.renderer = renderer
    }

    @MainActor
    public func applyUndo(layers: TextureLayersState, repository: UndoTextureInMemoryRepository) async throws {
        guard
            let undoTextureId,
            let newTexture = try await MTLTextureCreator.duplicateTexture(
                texture: repository.texture(id: undoTextureId),
                renderer: renderer
            )
        else { return }
/*
        try await layers.addLayer(
            layer: textureLayer,
            newTexture: newTexture,
            at: insertIndex
        )
 */
        //layers.requestFullCanvasUpdate()
    }
}
