//
//  Created by Eisuke Kusachi
//

import Foundation

@preconcurrency import MetalKit

public protocol UndoTextureInMemoryRepositoryProtocol: Actor {

    /// Returns the texture associated with the specified id
    func texture(_ id: UUID) -> MTLTexture?

    /// Adds a texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    func addTexture(newTexture: MTLTexture, id: UUID) throws

    /// Updates the texture. Since `MTLTexture` is a reference type, this texture must be a new instance
    func updateTexture(newTexture: MTLTexture, for id: UUID) async throws

    /// Removes the texture for the specified id
    func removeTexture(_ id: UUID) throws

    /// Removes all textures
    func removeAll()
}
