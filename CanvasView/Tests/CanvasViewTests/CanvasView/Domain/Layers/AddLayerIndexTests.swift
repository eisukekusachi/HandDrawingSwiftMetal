//
//  AddLayerIndexTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/05.
//

import Testing

@testable import CanvasView

/*
 In this app, layers with smaller indices are positioned further back. For example, moving a layer from index 0 to 1 brings it to the front.
*/
struct AddLayerIndexTests {

    @Test("Confirms the index position when adding a layer")
    func testNewInsertIndex() {
        let selectedIndex = 2
        let result = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        // A new layer is added one position above the currently selected layer
        #expect(result == 3)
    }
}
