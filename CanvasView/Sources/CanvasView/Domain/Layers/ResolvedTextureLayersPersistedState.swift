//
//  TextureLayersPersistedState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

public struct TextureLayersPersistedState: Sendable {

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

public extension TextureLayersPersistedState {
    init?(entity: TextureLayerArrayStorageEntity?) {
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

    init(
        _ model: TextureLayersArchiveModel
    ) {
        self.layers = model.layers
        self.layerIndex = model.layerIndex
        self.textureSize = model.textureSize
    }

    var selectedLayerId: LayerId? {
        guard !layers.isEmpty else { return nil }

        let index = layerIndex < layers.count ? layerIndex : 0
        return layers[index].id
    }
}
