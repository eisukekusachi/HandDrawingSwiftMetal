//
//  Created by Eisuke Kusachi
//

import Core
import MetalKit

extension InMemoryTextureRepository {

    /// App-wide in-memory texture cache (e.g. undo).
    @MainActor
    public static let shared: MTLTextureRepositoryProtocol = InMemoryTextureRepository(
        textures: [:]
    )
}
