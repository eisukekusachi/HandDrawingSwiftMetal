//
//  ResolvedCanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/11.
//

import UIKit

/// `CanvasConfiguration` with a determined texture size
public struct ResolvedCanvasConfiguration: Sendable {

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

public extension ResolvedCanvasConfiguration {

    init(
        configuration: CanvasConfiguration,
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
