//
//  TextureLayers.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/02/15.
//

import TextureLayerView

@MainActor
struct TextureLayers {

    let selectedIndex: Int
    let layers: [TextureLayerModel]

    init?(state: TextureLayersState) {
        guard
            let selectedIndex = state.selectedIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = state.layers.map { .init(item: $0) }
    }

    var bottomLayers: [TextureLayerModel] {
        layers.safeSlice(
            lower: 0,
            upper: selectedIndex - 1
        ).filter { $0.isVisible }
    }

    var topLayers: [TextureLayerModel] {
        layers.safeSlice(
            lower: selectedIndex + 1,
            upper: layers.count - 1
        ).filter { $0.isVisible }
    }
}
