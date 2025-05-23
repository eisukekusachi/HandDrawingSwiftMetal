//
//  TextureLayerDocumentsDirectorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Foundation

final class TextureLayerDocumentsDirectorySingletonRepository: TextureLayerRepositoryWrapper {

    static let shared = TextureLayerDocumentsDirectorySingletonRepository()

    private init() {
        super.init(repository: TextureLayerDocumentsDirectoryRepository(directoryName: "TextureStorage"))
    }

}
