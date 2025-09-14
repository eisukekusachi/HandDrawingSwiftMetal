//
//  ResolvedTextureLayserArrayConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

/// `TextureLayserArrayConfiguration` with a determined texture size
public struct ResolvedTextureLayserArrayConfiguration: Sendable {

    public let textureSize: CGSize

    public let layerIndex: Int
    public let layers: [TextureLayerModel]

    public init(
        projectName: String,
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel]
    ) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

public extension ResolvedTextureLayserArrayConfiguration {

    init(
        configuration: TextureLayserArrayConfiguration,
        resolvedTextureSize: CGSize
    ) async throws {

        self.textureSize = resolvedTextureSize

        self.layerIndex = configuration.layerIndex
        self.layers = configuration.layers
    }

    var selectedLayerId: UUID {
        let index = layerIndex < layers.count ? layerIndex : 0
        return layers[index].id
    }
}
