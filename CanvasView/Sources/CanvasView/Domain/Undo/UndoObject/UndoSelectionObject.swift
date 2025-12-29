//
//  UndoSelectionObject.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/20.
//

import Combine
import Foundation

/// An undo object for reverting layer selection
public final class UndoSelectionObject: UndoObject {

    public var textureLayer: TextureLayerModel

    public var undoTextureId: UndoTextureId? = nil

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    init(
        layer: TextureLayerModel
    ) {
        self.textureLayer = layer
    }

    public func applyUndo(layers: any TextureLayersProtocol, repository: UndoTextureInMemoryRepository) async throws {
        layers.selectLayer(
            textureLayer.id
        )
        layers.requestFullCanvasUpdate()
    }
}
