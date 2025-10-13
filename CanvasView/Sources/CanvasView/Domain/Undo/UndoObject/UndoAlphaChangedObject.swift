//
//  UndoAlphaChangedObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/28.
//

import Combine
import Foundation
import MetalKit

/// An undo object for updating a texture layer
public final class UndoAlphaChangedObject: UndoObject {

    /// Not used
    public let undoTextureId: UndoTextureId = UndoTextureId()

    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layer: TextureLayerModel,
        withNewAlpha alpha: Int
    ) {
        self.textureLayer = .init(
            id: layer.id,
            title: layer.title,
            alpha: alpha,
            isVisible: layer.isVisible
        )
    }

    @MainActor
    public func applyUndo(layers: TextureLayers, repository: TextureRepository) async throws {
        layers.updateAlpha(
            textureLayer.id,
            alpha: textureLayer.alpha
        )

        layers.requestFullCanvasUpdate()
    }
}
