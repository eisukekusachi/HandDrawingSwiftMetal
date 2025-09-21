//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct CanvasConfiguration {
    let projectConfiguration: ProjectConfiguration
    let textureLayerArrayConfiguration: TextureLayerArrayConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        projectConfiguration: ProjectConfiguration = .init(),
        textureLayerArrayConfiguration: TextureLayerArrayConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.projectConfiguration = projectConfiguration
        self.textureLayerArrayConfiguration = textureLayerArrayConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
