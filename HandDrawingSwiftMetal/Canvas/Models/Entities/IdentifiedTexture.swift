//
//  IdentifiedTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
struct IdentifiedTexture {
    var uuid: UUID
    var texture: MTLTexture?
}
