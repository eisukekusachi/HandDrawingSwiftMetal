//
//  ProjectConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct ProjectConfiguration: Sendable {
    /// The file name saved in the Documents folder
    public let projectName: String

    /// The size of the texture used for the canvas
    public let textureSize: CGSize?

    /// The index of the layer
    public let layerIndex: Int

    /// An array of layer models
    public let layers: [TextureLayerModel]

    public init(
        projectName: String = Calendar.currentDate,
        textureSize: CGSize? = nil,
        layerIndex: Int = 0,
        layers: [TextureLayerModel] = []
    ) {
        self.projectName = projectName
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

extension ProjectConfiguration {

    public init(
        _ configuration: Self,
        textureSize: CGSize? = nil,
        layerIndex: Int? = nil,
        layers: [TextureLayerModel]? = nil
    ) {
        self.projectName = configuration.projectName

        self.textureSize = textureSize ?? configuration.textureSize

        self.layerIndex = layerIndex ?? configuration.layerIndex
        self.layers = layers ?? configuration.layers
    }

    public init(
        projectName: String,
        model: CanvasModel
    ) {
        // `projectName` is the file name in the Documents folder and is not managed in `CanvasModel`
        self.projectName = projectName

        self.textureSize = model.textureSize

        self.layerIndex = model.layerIndex
        self.layers = model.layers
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
                    TextureLayerModel(
                        id: layer.id ?? UUID(),
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
}
