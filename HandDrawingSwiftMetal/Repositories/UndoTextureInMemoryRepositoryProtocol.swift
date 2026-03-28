//
//  UndoTextureInMemoryRepositoryProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/22.
//

import Foundation
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
protocol UndoTextureInMemoryRepositoryProtocol: AnyObject {

    /// Returns the texture associated with the specified `UndoTextureId`
    func texture(_ id: UndoTextureId) -> MTLTexture?

    /// Adds a texture.Since `MTLTexture` is a reference type, this texture must be a new instance
    func addTexture(newTexture: MTLTexture, id: UndoTextureId) throws

    /// Updates the texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    func updateTexture(newTexture: MTLTexture, for id: UndoTextureId) async throws

    /// Removes the texture for the specified `LayerId`
    func removeTexture(_ id: UndoTextureId) throws

    /// Removes all textures
    func removeAll()
}
