//
//  TextureUndoDocumentsDirectoryRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Foundation

final class TextureUndoDocumentsDirectorySingletonRepository: TextureRepositoryWrapper {

    static let shared = TextureUndoDocumentsDirectorySingletonRepository()

    private init() {
        super.init(repository: TextureDocumentsDirectoryRepository(directoryName: "UndoTexture"))
    }

}
