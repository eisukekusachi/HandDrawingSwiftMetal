//
//  TextureRepositoryEntity.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
struct TextureRepositoryEntity {
    var uuid: UUID
    var texture: MTLTexture?
}
