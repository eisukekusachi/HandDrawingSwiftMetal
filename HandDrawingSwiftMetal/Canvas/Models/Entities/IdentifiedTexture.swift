//
//  IdentifiedTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
struct IdentifiedTexture: Hashable {
    var uuid: UUID
    var texture: MTLTexture

    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    static func == (lhs: IdentifiedTexture, rhs: IdentifiedTexture) -> Bool {
        lhs.uuid == rhs.uuid
    }

    /// Converts a single IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from item: IdentifiedTexture) -> [UUID: MTLTexture] {
        [item.uuid: item.texture]
    }

    /// Converts a Set of IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from set: Set<IdentifiedTexture>) -> [UUID: MTLTexture] {
        Dictionary(
            uniqueKeysWithValues: set.compactMap { item in
                return (item.uuid, item.texture)
            }
        )
    }
}
