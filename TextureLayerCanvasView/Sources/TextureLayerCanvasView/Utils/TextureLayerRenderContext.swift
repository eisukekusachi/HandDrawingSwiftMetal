//
//  TextureLayerRenderContext.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/02/15.
//

import MetalKit

struct TextureLayerRenderContext {
    public let isVisible: Bool
    public let alpha: Int
    public let texture: MTLTexture?

    public init(
        isVisible: Bool,
        alpha: Int,
        texture: MTLTexture?
    ) {
        self.isVisible = isVisible
        self.alpha = alpha
        self.texture = texture
    }
}
