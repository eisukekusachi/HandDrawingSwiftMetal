//
//  TextureUndoDocumentsDirectorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/28.
//

import Foundation

/// Only saves textures to the documents directory, but does not restore them
final class TextureUndoDocumentsDirectorySingletonRepository: TextureRepositoryWrapper, @unchecked Sendable {

    static let shared = TextureUndoDocumentsDirectorySingletonRepository()

    private init() {
        super.init(
            repository: TextureDocumentsDirectoryRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "UndoStorage"
            )
        )
    }
}
