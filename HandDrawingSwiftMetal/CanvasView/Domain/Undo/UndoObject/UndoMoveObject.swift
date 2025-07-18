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
final class UndoMoveObject: UndoObject {

    /// Not used
    let undoTextureUUID: UUID = UUID()

    let textureLayer: TextureLayerModel

    let deinitSubject = PassthroughSubject<UndoObject, Never>()

    let selectedLayerId: UUID

    let indices: MoveLayerIndices

    var reversedObject: UndoMoveObject {
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

    init(
        indices: MoveLayerIndices,
        selectedLayerId: UUID,
        layer: TextureLayerModel
    ) {
        self.indices = indices
        self.selectedLayerId = selectedLayerId
        self.textureLayer = layer
    }

    func updateTextureLayerRepositoryIfNeeded(
        _ textureLayerRepository: TextureLayerRepository,
        using undoTextureRepository: TextureRepository
    ) -> AnyPublisher<Void, Error> {
        // Do not update the texture repository
        Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

}
