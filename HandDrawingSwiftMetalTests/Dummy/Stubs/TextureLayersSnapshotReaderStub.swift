//
//  Created by Eisuke Kusachi
//

import TextureLayerView
@testable import HandDrawingSwiftMetal

@MainActor
final class TextureLayersSnapshotReaderStub: TextureLayersSnapshotReading {

    var snapshot: TextureLayersSnapshot?
    private(set) var clearSavedLayersCallCount = 0

    init(snapshot: TextureLayersSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func savedLayersSnapshot() -> TextureLayersSnapshot? {
        snapshot
    }

    func clearSavedLayers() {
        clearSavedLayersCallCount += 1
    }
}
