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
}

extension TextureLayers {

    init?(state: TextureLayersState) {
        guard
            let selectedIndex = state.selectedIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = state.layers.map { .init(item: $0) }
    }
}
