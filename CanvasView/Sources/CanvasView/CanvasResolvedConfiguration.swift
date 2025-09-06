//
//  CanvasResolvedConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

public struct CanvasResolvedConfiguration: Sendable {

    public let projectName: String

    public let textureSize: CGSize

    public let layerIndex: Int
    public let layers: [TextureLayerModel]

    public init(
        projectName: String,
        textureSize: CGSize,
        layerIndex: Int,
        layers: [TextureLayerModel]
    ) {
        self.projectName = projectName
        self.textureSize = textureSize
        self.layerIndex = layerIndex
        self.layers = layers
    }
}

public extension CanvasResolvedConfiguration {

    init(
        configuration: ProjectConfiguration,
        resolvedTextureSize: CGSize
    ) async throws {

        self.textureSize = resolvedTextureSize

        self.projectName = configuration.projectName

        self.layerIndex = configuration.layerIndex
        self.layers = configuration.layers
    }

    var selectedLayerId: UUID {
        layers[layerIndex].id
    }
}
