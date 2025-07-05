//
//  RemoveLayerIndexTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/05.
//

import Foundation
import Testing

@testable import HandDrawingSwiftMetal

/*
 In this app, layers with smaller indices are positioned further back. For example, moving a layer from index 0 to 1 brings it to the front.
*/
struct RemoveLayerIndexTests {

    @Test("Confirms that selectedIndex is decremented after deletion when it is greater than 0.")
    func testSelectedIndexAfterDeletion_decrementsWhenGreaterThanZero() {
        let selectedIndex = 3
        let result = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedIndex)
        #expect(result == 2)
    }

    @Test("Confirms that selectedIndex does not go below 0 after deletion.")
    func testSelectedIndexAfterDeletion_doesNotGoBelowZero() {
        let selectedIndex = 0
        let result = RemoveLayerIndex.selectedIndexAfterDeletion(selectedIndex: selectedIndex)
        #expect(result == 0)
    }

}
