//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct CanvasConfiguration {
    let projectConfiguration: ProjectConfiguration
    let textureLayersConfiguration: TextureLayersConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        projectConfiguration: ProjectConfiguration = .init(),
        textureLayersConfiguration: TextureLayersConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.projectConfiguration = projectConfiguration
        self.textureLayersConfiguration = textureLayersConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
