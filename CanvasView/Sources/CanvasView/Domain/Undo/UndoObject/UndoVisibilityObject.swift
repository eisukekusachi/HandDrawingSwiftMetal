//
//  UndoVisibilityObject.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/21.
//

import Combine
import Foundation

/// An undo object for reverting layer visibility
public final class UndoVisibilityObject: UndoObject {
    public var undoTextureId: UndoTextureId? = nil

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    public let textureLayer: TextureLayerModel

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layer: TextureLayerModel,
    ) {
        self.textureLayer = layer
    }

    public func applyUndo(layers: any TextureLayersProtocol, repository: TextureInMemoryRepository) async throws {
        layers.updateVisibility(
            textureLayer.id,
            isVisible: textureLayer.isVisible
        )
        layers.requestFullCanvasUpdate()
    }
}
