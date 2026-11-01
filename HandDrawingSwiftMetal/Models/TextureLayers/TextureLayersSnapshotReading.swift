//
//  Created by Eisuke Kusachi
//

import TextureLayerView

/// Saved texture layer metadata for restore (Core Data model name is `TextureLayerStorage`).
@MainActor
protocol TextureLayersSnapshotReading: AnyObject {
    func savedLayersSnapshot() -> TextureLayersSnapshot?
    func clearSavedLayers()
}
