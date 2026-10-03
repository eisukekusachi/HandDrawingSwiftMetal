//
//  Created by Eisuke Kusachi
//

import Foundation
import Testing
@testable import HandDrawingSwiftMetal

struct MoveLayerIndicesTests {

    @Test
    func `Confirms the array destination index is one less when moving to a higher index`() async throws {
        let sourceIndex = 2
        let destinationIndex = 4

        let result = MoveLayerIndices.arrayDestinationIndex(
            moveLayerSourceIndex: sourceIndex,
            moveLayerDestinationIndex: destinationIndex
        )

        // Insertion happens before removal, so a higher destination shifts by one
        #expect(result == 3)
    }

    @Test
    func `Confirms the array destination index stays the same when moving to a lower index`() async throws {
        let sourceIndex = 4
        let destinationIndex = 2

        let result = MoveLayerIndices.arrayDestinationIndex(
            moveLayerSourceIndex: sourceIndex,
            moveLayerDestinationIndex: destinationIndex
        )

        #expect(result == 2)
    }

    @Test
    func `Confirms the move destination index is one greater when moving to a higher index`() async throws {
        let sourceIndex = 1
        let destinationIndex = 2

        let result = MoveLayerIndices.moveLayerDestinationIndex(
            arraySourceIndex: sourceIndex,
            arrayDestinationIndex: destinationIndex
        )

        #expect(result == 3)
    }

    @Test
    func `Confirms the move destination index stays the same when moving to a lower index`() async throws {
        let sourceIndex = 2
        let destinationIndex = 1

        let result = MoveLayerIndices.moveLayerDestinationIndex(
            arraySourceIndex: sourceIndex,
            arrayDestinationIndex: destinationIndex
        )

        #expect(result == 1)
    }

    @Test
    func `Confirms reversing an upward move subtracts one from the source index`() async throws {
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

    @Test
    func `Confirms reversing a downward move adds one to the destination index`() async throws {
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
