//
//  TextureLayerEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

public struct TextureLayerEntity: Codable, Equatable, Sendable {
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

    public init(textureName: String, title: String, alpha: Int, isVisible: Bool) {
        self.textureName = textureName
        self.title = title
        self.alpha = alpha
        self.isVisible = isVisible
    }
}

extension TextureLayerEntity {

    init(from model: TextureLayerModel) {
        self.textureName = model.id.uuidString
        self.title = model.title
        self.alpha = model.alpha
        self.isVisible = model.isVisible
    }

    /// Uses the filename as the ID, and generates a new one if it is not valid
    static func id(from entity: TextureLayerEntity) -> UUID {
        UUID.init(uuidString: entity.textureName) ?? UUID()
    }
}
