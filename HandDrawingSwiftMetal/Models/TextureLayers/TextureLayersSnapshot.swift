//
//  Created by Eisuke Kusachi
//

import Core
import TextureLayerView
import UIKit

@preconcurrency import CoreData

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

extension TextureLayersSnapshot {

    public init(entity: TextureLayerArrayEntity) {
        let layers: [TextureLayerModel] = entity.textureLayerItems?
            .compactMap { $0 as? TextureLayerEntity }
            .map { layer in
                TextureLayerModel(
                    id: layer.id ?? LayerId(),
                    title: layer.title ?? "",
                    alpha: Int(layer.alpha),
                    isVisible: layer.isVisible
                )
            } ?? []
        let layerIndex = layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0
        let textureSize = CGSize(
            width: Int(entity.textureWidth),
            height: Int(entity.textureHeight)
        )
        self.init(
            layers: layers,
            layerIndex: layerIndex,
            textureSize: textureSize
        )
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
