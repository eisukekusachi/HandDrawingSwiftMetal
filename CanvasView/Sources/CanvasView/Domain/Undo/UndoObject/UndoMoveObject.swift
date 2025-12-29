//
//  UndoMoveObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/26.
//

import Combine
import Foundation
import MetalKit

/// An undo object for moving a texture layer
public final class UndoMoveObject: UndoObject {

    /// Not used
    public let undoTextureId: UndoTextureId? = nil

    public let textureLayer: TextureLayerModel

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    public let selectedLayerId: LayerId

    public let indices: MoveLayerIndices

    public var reversedObject: UndoMoveObject {
        let sourceIndex = indices.sourceIndex
        let destinationIndex = MoveLayerIndices.arrayDestinationIndex(
            moveLayerSourceIndex: sourceIndex,
            moveLayerDestinationIndex: indices.destinationIndex
        )

        // Reverse the values
        let reversedSourceIndex = destinationIndex
        let reversedDestinationIndex = sourceIndex

        return .init(
            indices: .init(
                sourceIndexSet: IndexSet(integer: reversedSourceIndex),
                destinationIndex: MoveLayerIndices.moveLayerDestinationIndex(
                    arraySourceIndex: reversedSourceIndex,
                    arrayDestinationIndex: reversedDestinationIndex
                )
            ),
            selectedLayerId: selectedLayerId,
            layer: textureLayer
        )
    }

    deinit {
        deinitSubject.send(self)
    }

    public init(
        indices: MoveLayerIndices,
        selectedLayerId: LayerId,
        layer: TextureLayerModel
    ) {
        self.indices = indices
        self.selectedLayerId = selectedLayerId
        self.textureLayer = layer
    }

    @MainActor
    public func applyUndo(layers: any TextureLayersProtocol, repository: UndoTextureInMemoryRepository) async throws {
        layers.moveLayer(
            indices: indices
        )
        layers.requestFullCanvasUpdate()
    }
}
