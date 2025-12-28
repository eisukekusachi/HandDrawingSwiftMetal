//
//  TextureLayersState.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

public struct TextureLayersState: Sendable {

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

public extension TextureLayersState {
    init(entity: TextureLayerArrayStorageEntity?) throws {
        guard
            let entity else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Failed to unwrap optional value", bundle: .main)
            )
            Logger.error(error)
            throw error
        }

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
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Unable to find texture layer files", bundle: .main)
            )
            Logger.error(error)
            throw error
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
