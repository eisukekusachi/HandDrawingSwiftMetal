//
//  Created by Eisuke Kusachi
//

import Core

final class TextureLayerCanvasViewDependencies {

    let documentsTextureDataRepository: MTLTextureDataRepositoryProtocol

    @MainActor
    init(
        documentsTextureDataRepository: MTLTextureDataRepositoryProtocol? = nil
    ) {
        self.documentsTextureDataRepository = documentsTextureDataRepository ?? DocumentsTextureDataRepository.shared
    }
}
