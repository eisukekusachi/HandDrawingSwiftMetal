//
//  TextureLayersSnapshot.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import TextureLayerView
import UIKit

/// A struct that represents the snapshot of `TextureLayersState`.
/// Used when saving and restoring layer data.
public struct TextureLayersSnapshot: Sendable {

    public let layers: [TextureLayerModel]

    public let layerIndex: Int

    public let textureSize: CGSize

    public init(
        layers: [TextureLayerModel] = [],
        layerIndex: Int = 0,
        textureSize: CGSize,
        title: String = ""
    ) {
        if layers.isEmpty {
            self.layers = [
                .init(
                    id: LayerId(),
                    title: title,
                    alpha: 255,
                    isVisible: true
                )
            ]
        } else {
            self.layers = layers
        }
        self.layerIndex = max(0, min(layerIndex, self.layers.count - 1))
        self.textureSize = textureSize
    }
}

public extension TextureLayersSnapshot {
    var selectedLayerId: LayerId? {
        guard !layers.isEmpty else { return nil }

        let index = layerIndex < layers.count ? layerIndex : 0
        return layers[index].id
    }
}

extension TextureLayerItem {
    init(
        model: TextureLayerModel,
        thumbnail: UIImage? = nil
    ) {
        self.init(
            id: model.id,
            title: model.title,
            alpha: model.alpha,
            isVisible: model.isVisible,
            thumbnail: thumbnail
        )
    }
}
