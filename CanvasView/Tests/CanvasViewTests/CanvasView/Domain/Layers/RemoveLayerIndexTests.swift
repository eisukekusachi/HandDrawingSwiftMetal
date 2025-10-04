//
//  RemoveLayerIndexTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/05.
//

import Foundation
import Testing

@testable import CanvasView

/*
 In this app, layers are arranged in descending order by their indices
*/
struct RemoveLayerIndexTests {

    @Test("Confirms that deleting a non-zero indexed layer selects the layer at index - 1.")
    func testSelectedIndexAfterDeletion_decrementsWhenGreaterThanZero() {
        let selectedIndex = 3
        let result = RemoveLayerIndex.nextLayerIndexAfterDeletion(index: selectedIndex)
        #expect(result == 2)
    }

    @Test("Confirms that deleting a zero indexed layer selects the layer at index + 1.")
    func testSelectedIndexAfterDeletion_doesNotGoBelowZero() {
        let selectedIndex = 0
        let result = RemoveLayerIndex.nextLayerIndexAfterDeletion(index: selectedIndex)
        #expect(result == 1)
    }
}
