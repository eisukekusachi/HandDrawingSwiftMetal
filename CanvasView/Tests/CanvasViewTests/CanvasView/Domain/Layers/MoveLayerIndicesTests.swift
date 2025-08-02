//
//  MoveLayerIndicesTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/05.
//

import Foundation
import Testing

@testable import CanvasView

/*
 In this app, layers with smaller indices are positioned further back. For example, moving a layer from index 0 to 1 brings it to the front.

 Because moving a layer is implemented by copying the target layer to the destination index and then removing it from the source index,
 The moving layer index becomes one greater than the array index when destinationIndex is greater than sourceIndex.
*/
struct MoveLayerIndicesTests {

    struct ConvertMovingLayerIndexToArrayIndex {
        @Test("When the destination index is greater than the source index, confirms that 1 is subtracted from the destination array index.")
        func testArrayDestinationIndex_subtractsOneWhenMovingUpward() {
            let sourceIndex = 2
            let destinationIndex = 4

            let result = MoveLayerIndices.arrayDestinationIndex(
                moveLayerSourceIndex: sourceIndex,
                moveLayerDestinationIndex: destinationIndex
            )

            #expect(result == 3)
        }

        @Test("When the source index is greater than the destination index, confirms that the destination array index remains unchanged.")
        func testArrayDestinationIndex_noShiftWhenMovingDownward() {
            let sourceIndex = 4
            let destinationIndex = 2

            let result = MoveLayerIndices.arrayDestinationIndex(
                moveLayerSourceIndex: sourceIndex,
                moveLayerDestinationIndex: destinationIndex
            )

            #expect(result == 2)
        }
    }

    struct ConvertArrayIndexToMovingLayerIndex {
        @Test("When the destination index is greater than the source index, confirms that 1 is added to the destination moving layer index.")
        func testMoveLayerDestinationIndex_addsOneWhenMovingUpward() {
            let sourceIndex = 1
            let destinationIndex = 2

            let result = MoveLayerIndices.moveLayerDestinationIndex(
                arraySourceIndex: sourceIndex,
                arrayDestinationIndex: destinationIndex
            )

            #expect(result == 3)
        }

        @Test("When the destination index is greater than the source index, confirms that destinationIndex remains unchanged.")
        func testMoveLayerDestinationIndex_noChangeWhenMovingDownward() {
            let sourceIndex = 2
            let destinationIndex = 1

            let result = MoveLayerIndices.moveLayerDestinationIndex(
                arraySourceIndex: sourceIndex,
                arrayDestinationIndex: destinationIndex
            )

            #expect(result == 1)
        }
    }

    struct ReversedIndices {
        @Test("When reversing MoveLayerIndices where destinationIndex is greater than sourceIndex, 1 is subtracted from sourceIndexSet.")
        func testReversedIndices_subtractsOneFromSourceIndexSetWhenMovingUpward() {
            let original = MoveLayerIndices(
                sourceIndexSet: IndexSet(integer: 0),
                destinationIndex: 3
            )

            let layerCount = 3

            let reversedIndices = MoveLayerIndices.reversedIndices(
                indices: original,
                layerCount: layerCount
            )

            #expect(reversedIndices.sourceIndexSet == IndexSet(integer: 2))
            #expect(reversedIndices.destinationIndex == 0)
        }

        @Test("When reversing MoveLayerIndices where destinationIndex is less than sourceIndex, 1 is added to destinationIndex.")
        func testReversedIndices_addsOneToDestinationIndexWhenMovingDownward() {
            let original = MoveLayerIndices(
                sourceIndexSet: IndexSet(integer: 2),
                destinationIndex: 0
            )

            let layerCount = 3

            let reversedIndices = MoveLayerIndices.reversedIndices(
                indices: original,
                layerCount: layerCount
            )

            #expect(reversedIndices.sourceIndexSet == IndexSet(integer: 0))
            #expect(reversedIndices.destinationIndex == 3)
        }
    }

}
