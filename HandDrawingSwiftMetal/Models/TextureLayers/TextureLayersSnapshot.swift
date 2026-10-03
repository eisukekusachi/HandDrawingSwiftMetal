//
//  TextureLayersSnapshot.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import Core
import TextureLayerView
import UIKit

/// A struct that represents the snapshot of `TextureLayersState`.
/// Used when saving and restoring layer data.
public struct TextureLayersSnapshot: Codable, Equatable, Sendable {

    public let layers: [TextureLayerModel]

    public let layerIndex: Int

    public let textureSize: CGSize

    public init(
        layers: [TextureLayerModel],
        layerIndex: Int,
        textureSize: CGSize
    ) {
        self.layers = layers
        if layers.isEmpty {
            self.layerIndex = 0
        } else {
            self.layerIndex = max(0, min(layerIndex, layers.count - 1))
        }
        self.textureSize = textureSize
    }
}

extension TextureLayersSnapshot: LocalFileConvertible {
    public static var fileName: String { "data" }
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
