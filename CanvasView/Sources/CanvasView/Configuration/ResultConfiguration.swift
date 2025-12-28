//
//  ResultConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/27.
//

import Foundation

/// A struct created when `CanvasViewModel` setup is complete
public struct ResultConfiguration {
    public let textureLayers: any TextureLayersProtocol
    public let textureLayersPersistedState: TextureLayersPersistedState
}
