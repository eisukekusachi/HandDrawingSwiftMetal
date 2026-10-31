//
//  Created by Eisuke Kusachi
//

import Core
import Foundation
import TextureLayerView

@MainActor
final class HandDrawingViewDependencies {

    /// File operations for project zip files in the Documents directory.
    let fileManager: FileManaging

    /// Repository for texture data. Kept on disk so it remains after the app terminates.
    let documentsTextureDataRepository: MTLTextureDataRepositoryProtocol

    /// Repository for undo textures. Kept in memory because undo needs fast access.
    let inMemoryTextureRepository: MTLTextureRepositoryProtocol

    init(
        fileManager: FileManaging? = nil,
        documentsTextureDataRepository: MTLTextureDataRepositoryProtocol? = nil,
        inMemoryTextureRepository: MTLTextureRepositoryProtocol? = nil
    ) {
        self.fileManager = fileManager ?? FileManagerWrapper()
        self.documentsTextureDataRepository =
            documentsTextureDataRepository ?? DocumentsTextureDataRepository.shared
        self.inMemoryTextureRepository =
            inMemoryTextureRepository ?? InMemoryTextureRepository.shared
    }
}
