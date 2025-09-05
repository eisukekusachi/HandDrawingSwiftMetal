//
//  CanvasConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct CanvasConfiguration: Sendable {

    public let projectName: String

    public let textureSize: CGSize?

    public let layerIndex: Int
    public let layers: [TextureLayerItem]

    public init(
        projectName: String = Calendar.currentDate,
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerItem] = []
    ) {
        self.projectName = projectName
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

extension CanvasConfiguration {

    public init(
        projectName: String,
        model: CanvasModel
    ) {
        // Since the project name is the same as the folder name, it will not be managed in `CanvasEntity`
        self.projectName = projectName

        self.textureSize = model.textureSize

        self.layerIndex = model.layerIndex
        self.layers = model.layers.map {
            .init(textureName: $0.textureName, title: $0.title, alpha: $0.alpha, isVisible: $0.isVisible)
        }
    }

    public init(
        entity: CanvasStorageEntity
    ) {
        self.projectName = entity.projectName ?? Calendar.currentDate

        self.textureSize = .init(
            width: CGFloat(entity.textureWidth),
            height: CGFloat(entity.textureHeight)
        )

        if let layers = entity.textureLayers as? Set<TextureLayerStorageEntity> {
            self.layers = layers
                .sorted { $0.orderIndex < $1.orderIndex }
                .enumerated()
                .map { index, layer in
                    TextureLayerItem(
                        id: TextureLayerItem.id(from: layer.fileName),
                        title: layer.title ?? "",
                        alpha: Int(layer.alpha),
                        isVisible: layer.isVisible
                    )
                }
        } else {
            self.layers = []
        }

        self.layerIndex = self.layers.firstIndex(where: { $0.id == entity.selectedLayerId }) ?? 0
    }

    public init(
        _ configuration: Self,
        newTextureSize: CGSize
    ) {
        self.textureSize = newTextureSize

        self.projectName = configuration.projectName

        self.layerIndex = configuration.layerIndex
        self.layers = configuration.layers
    }

    public init(
        _ configuration: Self,
        newLayers: [TextureLayerItem]
    ) {
        self.projectName = configuration.projectName

        self.textureSize = configuration.textureSize

        self.layerIndex = configuration.layerIndex
        self.layers = newLayers
    }
}
