//
//  TextureLayserArrayConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct TextureLayserArrayConfiguration: Sendable {
    /// The size of the texture used for the canvas.
    /// If nothing is set, the screen size is applied.
    public let textureSize: CGSize?

    /// The index of the layer
    public let layerIndex: Int

    /// An array of layer models
    public let layers: [TextureLayerModel]

    public init(
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerModel] = []
    ) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

extension TextureLayserArrayConfiguration {

    public init(
        _ configuration: Self,
        textureSize: CGSize? = nil,
        layerIndex: Int? = nil,
        layers: [TextureLayerModel]? = nil
    ) {
        self.textureSize = textureSize ?? configuration.textureSize

        self.layerIndex = layerIndex ?? configuration.layerIndex
        self.layers = layers ?? configuration.layers
    }
}
