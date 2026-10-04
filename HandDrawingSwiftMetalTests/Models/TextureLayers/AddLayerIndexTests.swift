//
//  Created by Eisuke Kusachi
//

import Testing
@testable import HandDrawingSwiftMetal

struct AddLayerIndexTests {

    @Test
    func `Confirms a new layer is inserted one position above the selected layer`() async throws {
        let selectedIndex = 2

        let result = AddLayerIndex.insertIndex(selectedIndex: selectedIndex)

        #expect(result == 3)
    }
}
