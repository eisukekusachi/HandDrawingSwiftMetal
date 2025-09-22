//
//  TextureLayerArrayConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct TextureLayerArrayConfiguration: Sendable {
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

extension TextureLayerArrayConfiguration {

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

    public init?(entity: TextureLayerArrayStorageEntity?) {
        guard let entity else { return nil }

        self.layers = entity.textureLayerArray?
            .compactMap { $0 as? TextureLayerStorageEntity }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { layer -> TextureLayerModel in
                .init(
                    id: layer.id ?? UUID(),
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
