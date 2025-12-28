//
//  TextureLayersPersistedState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

/// A struct that represents the persisted state of texture layers
public struct TextureLayersPersistedState: Sendable {

    /// An array of layer models
    public let layers: [TextureLayerModel]

    /// The size of the texture used for the canvas.
    /// If nothing is set, the screen size is applied.
    public let textureSize: CGSize?

    /// The index of the layer
    public let layerIndex: Int

    public init(
        layers: [TextureLayerModel] = [],
        layerIndex: Int = 0,
        textureSize: CGSize? = nil
    ) {
        self.layers = layers
        self.layerIndex = layerIndex
        self.textureSize = textureSize
    }
}

extension TextureLayersPersistedState {

    public init(
        _ configuration: Self,
        layers: [TextureLayerModel]? = nil,
        layerIndex: Int? = nil,
        textureSize: CGSize? = nil
    ) {
        self.layers = layers ?? configuration.layers
        self.layerIndex = layerIndex ?? configuration.layerIndex
        self.textureSize = textureSize ?? configuration.textureSize
    }

    public init(
        _ model: TextureLayersArchiveModel
    ) {
        self.layers = model.layers
        self.layerIndex = model.layerIndex
        self.textureSize = model.textureSize
    }

    public init?(entity: TextureLayerArrayStorageEntity?) {
        guard let entity else { return nil }

        self.layers = entity.textureLayerArray?
            .compactMap { $0 as? TextureLayerStorageEntity }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { layer -> TextureLayerModel in
                .init(
                    id: layer.id ?? LayerId(),
                    title: layer.title ?? "",
                    alpha: Int(layer.alpha),
                    isVisible: layer.isVisible
                )
            } ?? []
        self.layerIndex = layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0
        self.textureSize = .init(width: Int(entity.textureWidth), height: Int(entity.textureHeight))

        // Return nil if the layers are nil or the texture size is zero
        if layers.isEmpty || textureSize == .zero {
            return nil
        }
    }
}
