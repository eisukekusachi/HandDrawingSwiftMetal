//
//  Created by Eisuke Kusachi
//

import Core
import MetalKit

/// In-memory GPU textures for undo
extension InMemoryTextureRepository {

    /// App-wide instance of that cache.
    @MainActor
    public static let shared: MTLTextureRepositoryProtocol = InMemoryTextureRepository(
        textures: [:]
    )
}
