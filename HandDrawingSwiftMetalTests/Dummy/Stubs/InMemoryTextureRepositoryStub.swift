//
//  Created by Eisuke Kusachi
//

import Core
import Foundation
import MetalKit

final actor InMemoryTextureRepositoryStub: MTLTextureRepositoryProtocol {

    private var textures: [UUID: MTLTexture] = [:]

    func texture(_ id: UUID) -> MTLTexture? {
        textures[id]
    }

    func addTexture(newTexture: MTLTexture, id: UUID) throws {
        textures[id] = newTexture
    }

    func updateTexture(newTexture: MTLTexture, for id: UUID) async throws {
        textures[id] = newTexture
    }

    func removeTexture(_ id: UUID) throws {
        textures.removeValue(forKey: id)
    }

    func removeAll() {
        textures = [:]
    }
}
