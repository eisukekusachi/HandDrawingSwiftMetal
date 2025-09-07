//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/10.
//

import UIKit

public struct CanvasConfiguration: Sendable {
    /// The file name saved in the Documents folder
    public let projectName: String

    /// The size of the texture used for the canvas.
    /// If nothing is set, the screen size is applied.
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

extension CanvasConfiguration {

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
        coreDataEntity entity: CanvasStorageEntity
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
                        fileName: layer.fileName ?? UUID().uuidString,
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
