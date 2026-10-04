//
//  Created by Eisuke Kusachi
//

import Foundation

@preconcurrency import MetalKit

/// A repository that manages textures for undo operations.
/// The textures are stored in memory to avoid blocking the main thread.
public final actor UndoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol {

    public static let shared: UndoTextureInMemoryRepositoryProtocol = UndoTextureInMemoryRepository(
        textures: [:]
    )

    /// A dictionary with id as the key and MTLTexture as the value
    private(set) var textures: [UUID: MTLTexture] = [:]

    init(
        textures: [UUID: MTLTexture] = [:]
    ) {
        self.textures = textures
    }

    /// Returns the texture associated with the specified id
    public func texture(_ id: UUID) -> MTLTexture? {
        textures[id]
    }

    /// Adds a texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    public func addTexture(newTexture: MTLTexture, id: UUID) throws {
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
    public func updateTexture(newTexture: MTLTexture, for id: UUID) async throws {
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

    /// Removes the texture for the specified id
    public func removeTexture(_ id: UUID) throws {
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
