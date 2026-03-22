//
//  UndoTextureInMemoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation
import TextureLayerView

@preconcurrency import MetalKit

/// A repository that manages textures for undo operations.
/// The textures are stored in memory to avoid blocking the main thread.
@MainActor
public final class UndoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol {

    public static let shared = UndoTextureInMemoryRepository(
        textures: [:]
    )

    /// A dictionary with `LayerId` as the key and MTLTexture as the value
    private(set) var textures: [LayerId: MTLTexture?] = [:]

    public init(
        textures: [LayerId: MTLTexture?] = [:]
    ) {
        self.textures = textures
    }

    /// Returns the texture associated with the specified `LayerId`
    public func texture(id: LayerId) -> MTLTexture? {
        textures[id] as? MTLTexture
    }

    /// Adds a texture.Since `MTLTexture` is a reference type, this texture must be a new instance
    public func addTexture(newTexture: MTLTexture, id: LayerId) throws {
        // If it doesn’t exist, add it
        guard textures[id] == nil else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "File already exists")
            )
            Logger.error(error)
            throw error
        }
        textures[id] = newTexture
    }

    /// Updates the texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    public func updateTexture(newTexture: MTLTexture, for id: LayerId) async throws {
        guard self.textures[id] != nil else {
            let error = NSError(
                title: String(localized: "Error"),
                message: "\(String(localized: "File not found")):\(id.uuidString)"
            )
            Logger.error(error)
            throw error
        }
        textures[id] = newTexture
    }

    /// Removes all textures
    public func removeAll() {
        textures = [:]
    }

    /// Removes the texture for the specified `LayerId`
    public func removeTexture(_ id: LayerId) throws {
        // If the file exists, delete it
        guard textures.keys.contains(id) else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to find \(id.uuidString)")
            )
            throw error
        }
        textures.removeValue(forKey: id)
    }
}
