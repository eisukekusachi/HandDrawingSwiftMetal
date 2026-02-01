//
//  TextureLayersArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct TextureLayersArchiveModel: Codable, Equatable {

    public let layers: [TextureLayerModel]
    public let layerIndex: Int
    public let textureSize: CGSize

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
