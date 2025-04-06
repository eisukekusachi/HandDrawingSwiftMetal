//
//  TextureLayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

struct TextureLayerEntity: Codable, Equatable {
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

extension TextureLayerEntity {

    init(from model: TextureLayerModel) {
        self.textureName = model.id.uuidString
        self.title = model.title
        self.alpha = model.alpha
        self.isVisible = model.isVisible
    }

}
