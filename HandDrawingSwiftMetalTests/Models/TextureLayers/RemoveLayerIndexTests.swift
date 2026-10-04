//
//  Created by Eisuke Kusachi
//

import Testing
@testable import HandDrawingSwiftMetal

struct RemoveLayerIndexTests {

    @Test
    func `Confirms deleting a layer above index 0 selects the previous layer`() async throws {
        let selectedIndex = 3

        let result = RemoveLayerIndex.nextLayerIndexAfterDeletion(index: selectedIndex)

        #expect(result == 2)
    }

    @Test
    func `Confirms deleting the layer at index 0 selects the next layer`() async throws {
        let selectedIndex = 0

        let result = RemoveLayerIndex.nextLayerIndexAfterDeletion(index: selectedIndex)

        #expect(result == 1)
    }
}
