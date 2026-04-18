//
//  TextureLayersRenderContext.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/02/15.
//

import TextureLayerView

@MainActor
struct TextureLayersRenderContext {

    public let selectedIndex: Int
    public let layers: [TextureLayerModel]

    public init?(state: TextureLayersState) {
        guard
            let selectedIndex = state.selectedIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = state.layers.map { .init(item: $0) }
    }
}
