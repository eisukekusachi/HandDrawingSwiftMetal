//
//  TextureLayerConfiguration.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/18.
//

import UIKit

public struct TextureLayerConfiguration {
    public let textureLayers: TextureLayers

    public let defaultBackgroundColor: UIColor
    public let selectedBackgroundColor: UIColor

    public init(
        textureLayers: TextureLayers,
        defaultBackgroundColor: UIColor = .white,
        selectedBackgroundColor: UIColor = .black
    ) {
        self.textureLayers = textureLayers
        self.defaultBackgroundColor = defaultBackgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
    }
}
