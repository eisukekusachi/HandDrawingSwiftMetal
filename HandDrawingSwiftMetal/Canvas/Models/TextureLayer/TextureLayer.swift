//
//  TextureLayer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/30.
//

import MetalKit
/// A layer with a texture
struct TextureLayer: TextureLayerProtocol {
    /// The unique identifier for the layer
    let id: UUID = UUID()
    /// The texture of the layer
    var texture: MTLTexture
    /// The name of the layer
    var title: String
    /// The thumbnail image of the layer
    var thumbnail: UIImage?
    /// The opacity of the layer
    var alpha: Int = 255
    /// Whether the layer is visible or not
    var isVisible: Bool = true

}

extension TextureLayer {

    mutating func updateThumbnail() {
        thumbnail = texture.upsideDownUIImage?.resize(width: 64)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

}
