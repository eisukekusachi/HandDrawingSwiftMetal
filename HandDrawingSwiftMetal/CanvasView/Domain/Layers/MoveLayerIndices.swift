//
//  MoveLayerIndices.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/02.
//

import Foundation

struct MoveLayerIndices {

    let sourceIndexSet: IndexSet

    let destinationIndex: Int

    var sourceIndex: Int {
        sourceIndexSet.first ?? 0
    }

    /// Converts a move operation destination index to the array index
    static func arrayDestinationIndex(moveLayerSourceIndex: Int, moveLayerDestinationIndex: Int) -> Int {
        // In an array move operation, the value is inserted before it is removed.
        // When moving a value to a higher index, the insertion shifts the array,
        // so the destination index becomes one position ahead of the expected array index.
        // Subtract 1 to get the correct array index when necessary.
        var moveLayerDestinationIndex = moveLayerDestinationIndex
        if moveLayerSourceIndex < moveLayerDestinationIndex {
            moveLayerDestinationIndex -= 1
        }
        return moveLayerDestinationIndex
    }

    /// Converts an array index to the index used in a move operation
    static func moveLayerDestinationIndex(arraySourceIndex: Int, arrayDestinationIndex: Int) -> Int {
        // Add 1 to the destination index when moving a value to a higher position
        arrayDestinationIndex > arraySourceIndex ? arrayDestinationIndex + 1 : arrayDestinationIndex
    }

    static func reversedIndices(indices: Self, layerCount: Int) -> Self {
        let sourceIndex = indices.sourceIndex
        let destinationIndex = arrayDestinationIndex(
            moveLayerSourceIndex: sourceIndex,
            moveLayerDestinationIndex: indices.destinationIndex
        )

        // Reverse the values
        let reversedSourceIndex: Int = (layerCount - 1) - sourceIndex
        let reversedDestinationIndex: Int = (layerCount - 1) - destinationIndex

        return .init(
            sourceIndexSet: IndexSet(integer: reversedSourceIndex),
            destinationIndex: MoveLayerIndices.moveLayerDestinationIndex(
                arraySourceIndex: reversedSourceIndex,
                arrayDestinationIndex: reversedDestinationIndex
            )
        )
    }

}
