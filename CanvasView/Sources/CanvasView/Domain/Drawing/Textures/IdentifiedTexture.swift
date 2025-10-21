//
//  IdentifiedTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

@preconcurrency import MetalKit

/// A struct that represents a texture entity with `UUID` and `MTLTexture`
public struct IdentifiedTexture: Hashable, @unchecked Sendable {
    public let id: UUID
    public let texture: MTLTexture

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: IdentifiedTexture, rhs: IdentifiedTexture) -> Bool {
        lhs.id == rhs.id
    }

    /// Converts a single IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from item: IdentifiedTexture) -> [UUID: MTLTexture] {
        [item.id: item.texture]
    }

    /// Converts a Set of IdentifiedTexture to a dictionary [UUID: MTLTexture]
    static func dictionary(from set: Set<IdentifiedTexture>) -> [UUID: MTLTexture] {
        Dictionary(
            uniqueKeysWithValues: set.compactMap { item in
                return (item.id, item.texture)
            }
        )
    }

    public init(id: UUID, texture: MTLTexture) {
        self.id = id
        self.texture = texture
    }
}

extension IdentifiedTexture: LocalFileConvertible {
    public var fileName: String {
        id.uuidString
    }
    public func write(to url: URL) throws {
        try FileOutput.saveTextureAsData(bytes: self.texture.bytes, to: url)
    }
}
