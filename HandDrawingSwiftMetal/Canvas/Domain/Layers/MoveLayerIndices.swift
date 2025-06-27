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
    static func normalizedDestinationIndex(sourceIndex: Int, destinationIndex: Int) -> Int {
        // In an array move operation, the value is inserted before it is removed.
        // When moving a value to a higher index, the insertion shifts the array,
        // so the destination index becomes one position ahead of the expected array index.
        // Subtract 1 to get the correct array index when necessary.
        var destinationIndex = destinationIndex
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }
        return destinationIndex
    }

    /// Converts an array index to the index used in a move operation
    static func moveLayerDestinationIndex(sourceIndex: Int, destinationIndex: Int) -> Int {
        // Add 1 to the destination index when moving a value to a higher position
        destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
    }

    static func reversedIndices(indices: Self, layerCount: Int) -> Self {
        let sourceIndex = indices.sourceIndex
        let destinationIndex = normalizedDestinationIndex(
            sourceIndex: sourceIndex,
            destinationIndex: indices.destinationIndex
        )

        // Reverse the values
        let reversedSourceIndex: Int = (layerCount - 1) - sourceIndex
        let reversedDestinationIndex: Int = (layerCount - 1) - destinationIndex

        return .init(
            sourceIndexSet: IndexSet(integer: reversedSourceIndex),
            destinationIndex: MoveLayerIndices.moveLayerDestinationIndex(
                sourceIndex: reversedSourceIndex,
                destinationIndex: reversedDestinationIndex
            )
        )
    }

}
