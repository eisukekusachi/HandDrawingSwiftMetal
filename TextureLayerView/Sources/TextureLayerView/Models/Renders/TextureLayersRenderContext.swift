//
//  TextureLayersRenderContext.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/02/15.
//

import Foundation

@MainActor
public struct TextureLayersRenderContext {

    public let selectedIndex: Int
    public let layers: [TextureLayerModel]

    public init?(textureLayers: any TextureLayersProtocol) {
        guard
            let selectedIndex = textureLayers.selectedIndex
        else { return nil }
        self.selectedIndex = selectedIndex
        self.layers = textureLayers.layers.map { .init(item: $0) }
    }
}
