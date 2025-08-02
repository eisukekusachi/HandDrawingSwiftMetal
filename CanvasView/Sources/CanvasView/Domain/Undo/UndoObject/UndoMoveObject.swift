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
    public let undoTextureUUID: UUID = UUID()

    public let textureLayer: TextureLayerItem

    public let deinitSubject = PassthroughSubject<UndoObject, Never>()

    public let selectedLayerId: UUID

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
        selectedLayerId: UUID,
        layer: TextureLayerItem
    ) {
        self.indices = indices
        self.selectedLayerId = selectedLayerId
        self.textureLayer = layer
    }

    public func performTextureOperation(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository
    ) async throws {
        // Do nothing
    }
}
