//
//  TextureLayerEvent.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/20.
//

import Foundation
public enum TextureLayerEvent {
    /// Adds a new texture layer
    case addLayer
    /// Removes a texture layer
    case removeLayer
    /// Selects a texture layer
    case selectLayer
    /// Edits a texture layer
    case editLayer
    /// Toggles the visibility of a texture layer
    case changeVisibility
    /// Moves a texture layer to a different position
    case moveLayer
    /// Changes the alpha (opacity) of a texture layer
    case changeLayerAlpha
}
