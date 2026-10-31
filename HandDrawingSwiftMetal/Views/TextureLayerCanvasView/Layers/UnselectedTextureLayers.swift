//
//  Created by Eisuke Kusachi
//

import TextureLayerView

/// Visible layers below and above the selected layer.
/// The selected layer is excluded and composited separately as `SelectedTextureLayer`.
@MainActor
struct UnselectedTextureLayers {

    /// Visible layers below the selected layer.
    var bottomLayers: [TextureLayerItem] {
        textureLayers.layers.safeSlice(
            lower: 0,
            upper: textureLayers.selectedIndex - 1
        ).filter { $0.isVisible }
    }

    /// Visible layers above the selected layer.
    var topLayers: [TextureLayerItem] {
        textureLayers.layers.safeSlice(
            lower: textureLayers.selectedIndex + 1,
            upper: textureLayers.layers.count - 1
        ).filter { $0.isVisible }
    }

    private let textureLayers: TextureLayers

    init(textureLayers: TextureLayers) {
        self.textureLayers = textureLayers
    }
}
