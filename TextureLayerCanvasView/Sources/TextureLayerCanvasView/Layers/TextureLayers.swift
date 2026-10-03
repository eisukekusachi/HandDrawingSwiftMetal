//
//  Created by Eisuke Kusachi
//

@MainActor
struct TextureLayers {

    let selectedIndex: Int
    let layers: [CanvasLayerSnapshot]
}

extension TextureLayers {

    init?(source: TextureLayerCanvasProtocol) {
        guard
            let selectedIndex = source.selectedLayerIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = source.layerSnapshots
    }
}
