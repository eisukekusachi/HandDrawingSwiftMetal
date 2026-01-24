//
//  CanvasConfigurationResult.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/27.
//

import Foundation

/// A struct created when `CanvasView` setup is complete
public struct CanvasConfigurationResult {

    public let textureSize: CGSize

    public let textureLayers: any TextureLayersProtocol

    public init(
        textureSize: CGSize,
        textureLayers: any TextureLayersProtocol
    ) {
        self.textureSize = textureSize
        self.textureLayers = textureLayers
    }
}
