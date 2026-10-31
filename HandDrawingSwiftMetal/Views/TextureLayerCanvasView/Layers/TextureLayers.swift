//
//  Created by Eisuke Kusachi
//

import TextureLayerView

@MainActor
struct TextureLayers {

    let selectedIndex: Int
    let layers: [TextureLayerItem]
}

extension TextureLayers {

    init?(source: TextureLayerCanvasProtocol) {
        guard
            let selectedIndex = source.selectedLayerIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = source.layers
    }
}
