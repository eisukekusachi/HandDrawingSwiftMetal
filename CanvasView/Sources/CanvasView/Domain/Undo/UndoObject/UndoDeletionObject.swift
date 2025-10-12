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
    public let undoTextureId: UndoTextureId = UndoTextureId()

    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    public let selectedLayerIdAfterDeletion: LayerId

    deinit {
        deinitSubject.send(self)
    }

    public init(
        layerToBeDeleted textureLayer: TextureLayerModel,
        selectedLayerIdAfterDeletion layerId: LayerId
    ) {
        self.textureLayer = textureLayer
        self.selectedLayerIdAfterDeletion = layerId
    }
}
