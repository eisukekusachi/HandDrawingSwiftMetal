//
//  ImageLayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/03.
//

import MetalKit

struct ImageLayerEntity: Codable, Equatable {
    /// The filename of the texture
    /// MTLTexture cannot be encoded into JSON,
    /// the texture is saved as a file, and this struct holds the `textureName` of the texture.
    let textureName: String
    /// The name of the layer
    let title: String
    /// The opacity of the layer
    let alpha: Int
    /// Whether the layer is visible or not
    let isVisible: Bool

}
