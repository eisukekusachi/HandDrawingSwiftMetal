//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import Foundation

public struct CanvasConfiguration {
    let textureLayserArrayConfiguration: TextureLayserArrayConfiguration
    let environmentConfiguration: EnvironmentConfiguration

    public init(
        textureLayserArrayConfiguration: TextureLayserArrayConfiguration = .init(),
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        self.textureLayserArrayConfiguration = textureLayserArrayConfiguration
        self.environmentConfiguration = environmentConfiguration
    }
}
