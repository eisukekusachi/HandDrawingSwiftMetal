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
        layers.safeSlice(
            lower: 0,
            upper: selectedIndex - 1
        ).filter { $0.isVisible }
    }

    /// Visible layers above the selected layer.
    var topLayers: [TextureLayerItem] {
        layers.safeSlice(
            lower: selectedIndex + 1,
            upper: layers.count - 1
        ).filter { $0.isVisible }
    }

    private let layers: [TextureLayerItem]
    private let selectedIndex: Int

    init(layers: [TextureLayerItem], selectedIndex: Int) {
        self.layers = layers
        self.selectedIndex = selectedIndex
    }
}

extension UnselectedTextureLayers {

    init?(textureLayers: TextureLayersCompositingProtocol) {
        guard let selectedIndex = textureLayers.selectedLayerIndex else { return nil }
        self.init(layers: textureLayers.layers, selectedIndex: selectedIndex)
    }
}
