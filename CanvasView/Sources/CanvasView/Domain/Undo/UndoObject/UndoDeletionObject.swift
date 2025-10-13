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

    @MainActor
    public func applyUndo(layers: TextureLayers, repository: TextureRepository) async throws {
        guard
            let index = layers.index(for: textureLayer.id)
        else {
            let message = "id: \(textureLayer.id.uuidString)"
            Logger.error(String(format: String(localized: "Unable to find %@", bundle: .module), message))
            return
        }

        try await layers.removeLayer(
            layerIndexToDelete: index
        )

        layers.requestFullCanvasUpdate()
    }
}
