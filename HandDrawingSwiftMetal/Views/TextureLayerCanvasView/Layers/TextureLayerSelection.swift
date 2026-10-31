//
//  Created by Eisuke Kusachi
//

import TextureLayerView

@MainActor
struct TextureLayerSelection {

    let textureLayers: TextureLayers

    var bottomLayers: [TextureLayerItem] {
        textureLayers.layers.safeSlice(
            lower: 0,
            upper: textureLayers.selectedIndex - 1
        ).filter { $0.isVisible }
    }

    var topLayers: [TextureLayerItem] {
        textureLayers.layers.safeSlice(
            lower: textureLayers.selectedIndex + 1,
            upper: textureLayers.layers.count - 1
        ).filter { $0.isVisible }
    }
}
