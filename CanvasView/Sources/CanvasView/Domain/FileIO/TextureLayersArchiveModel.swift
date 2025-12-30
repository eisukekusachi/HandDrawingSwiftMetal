//
//  TextureLayersArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct TextureLayersArchiveModel: Codable, Equatable {

    let layers: [TextureLayerModel]
    let layerIndex: Int
    let textureSize: CGSize

    public init(
        layers: [TextureLayerModel],
        layerIndex: Int,
        textureSize: CGSize
    ) {
        self.layers = layers
        self.layerIndex = layerIndex
        self.textureSize = textureSize
    }
}

extension TextureLayersArchiveModel: LocalFileConvertible {
    public static var fileName: String { "data" }
}
