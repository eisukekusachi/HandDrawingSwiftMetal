//
//  ResolvedTextureLayersConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

/// `TextureLayersConfiguration` with a determined texture size
public struct ResolvedTextureLayersConfiguration: Sendable {

    public let textureSize: CGSize

    public let layerIndex: Int
    public let layers: [TextureLayerModel]

    public init(
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel]
    ) {
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

public extension ResolvedTextureLayersConfiguration {

    init(
        textureLayersPersistedState: TextureLayersPersistedState,
        resolvedTextureSize: CGSize
    ) async throws {
        self.textureSize = resolvedTextureSize
        self.layerIndex = textureLayersPersistedState.layerIndex
        self.layers = textureLayersPersistedState.layers
    }

    var selectedLayerId: LayerId? {
        guard !layers.isEmpty else { return nil }

        let index = layerIndex < layers.count ? layerIndex : 0
        return layers[index].id
    }
}
