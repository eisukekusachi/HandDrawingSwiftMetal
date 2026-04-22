//
//  TextureLayerSelection.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/22.
//

import TextureLayerView

struct TextureLayerSelection {

    let textureLayers: TextureLayers

    var bottomLayers: [TextureLayerModel] {
        textureLayers.layers.safeSlice(
            lower: 0,
            upper: textureLayers.selectedIndex - 1
        ).filter { $0.isVisible }
    }

    var topLayers: [TextureLayerModel] {
        textureLayers.layers.safeSlice(
            lower: textureLayers.selectedIndex + 1,
            upper: textureLayers.layers.count - 1
        ).filter { $0.isVisible }
    }
}
