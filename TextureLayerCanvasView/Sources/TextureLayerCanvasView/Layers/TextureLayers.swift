//
//  TextureLayers.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/02/15.
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
