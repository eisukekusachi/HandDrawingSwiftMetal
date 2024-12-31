//
//  UndoMoveData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import Foundation

/// A structure used for undoing array movements
/// array movement is performed by duplicating the `fromIndex` element, inserting it at the `toIndex` position in the array, and then removing the `fromIndex`
/// this structure holds the variables required for that process
struct UndoMoveData {
    /// Index where an element is inserted during array movement
    let fromIndex: Int
    /// Index where an element is removed during array movement
    let toIndex: Int
    /// Selected index before the move
    let selectedIndex: Int
    /// Selected index after the move
    let selectedIndexAfterMove: Int
}

extension UndoMoveData {
    init(
        source: Int,
        destination: Int,
        selectedIndex: Int,
        selectedIndexAfterMove: Int
    ) {
        // Undoing the move operation, swap the insert and remove actions
        let undoSource = destination
        let undoDestination = source

        self.fromIndex = UndoMoveData.getMoveFromIndex(source: undoSource, destination: undoDestination)
        self.toIndex = UndoMoveData.getMoveToIndex(source: undoSource, destination: undoDestination)
        self.selectedIndex = selectedIndex
        self.selectedIndexAfterMove = selectedIndexAfterMove
    }

    /// Returns the adjusted `source` by adding 1 when moving an element from a larger index to a smaller index in an array
    /// to account for the duplication and insertion of the source element.
    static func getMoveFromIndex(
        source: Int,
        destination: Int
    ) -> Int {
        source > destination ? source + 1 : source
    }
    /// Returns the adjusted `destination` by adding 1 when moving an element from a smaller index to a larger index in an array
    /// to account for the duplication and insertion of the source element.
    static func getMoveToIndex(
        source: Int,
        destination: Int
    ) -> Int {
        destination > source ? destination + 1 : destination
    }

    /// Returns `toIndex`, subtracting 1 if `toIndex` is greater than `fromIndex`
    /// because the `toIndex` returned by `onMove(perform:)` has 1 added to account for the duplicated source element
    /// when `toIndex` is larger than `fromIndex`.
    static func getMoveDestination(
        fromIndex: Int,
        toIndex: Int
    ) -> Int {
        toIndex > fromIndex ? toIndex - 1: toIndex
    }

    /// Returns the selected index based on the source index, destination index, and the currently selected element’s index in the array
    static func makeSelectedIndexAfterMove(
        source: Int,
        destination: Int,
        selectedIndex: Int
    ) -> Int {
        var resultIndex = destination

        // Layer movement can be performed even on a layer that is not selected
        if selectedIndex != source {
            resultIndex = selectedIndex

            if destination <= selectedIndex && selectedIndex < source {
                // If the moving layer crosses over the selected layer and moves to a smaller index, add 1 to `resultIndex`
                resultIndex += 1

            } else if destination >= selectedIndex && selectedIndex > source {
                // If the moving layer crosses over the selected layer and moves to a larger index, subtract 1 from `resultIndex`
                resultIndex -= 1
            }
        }

        return resultIndex
    }

}
