//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct CanvasConfiguration {
    let projectConfiguration: ProjectConfiguration
    let textureLayserArrayConfiguration: TextureLayserArrayConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        projectConfiguration: ProjectConfiguration = .init(),
        textureLayserArrayConfiguration: TextureLayserArrayConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.projectConfiguration = projectConfiguration
        self.textureLayserArrayConfiguration = textureLayserArrayConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
