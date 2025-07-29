//
//  IdentifiedTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

@preconcurrency import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
public struct IdentifiedTexture: Hashable, @unchecked Sendable {
    public let uuid: UUID
    public let texture: MTLTexture

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    public static func == (lhs: IdentifiedTexture, rhs: IdentifiedTexture) -> Bool {
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

    public init(uuid: UUID, texture: MTLTexture) {
        self.uuid = uuid
        self.texture = texture
    }
}

extension IdentifiedTexture: LocalFileConvertible {
    public func write(to url: URL) throws {
        try FileOutput.saveTextureAsData(bytes: self.texture.bytes, to: url)
    }
}
