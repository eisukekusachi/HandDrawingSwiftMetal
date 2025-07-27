//
//  TextureUndoInMemorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/06/29.
//

import Foundation

final class TextureUndoInMemorySingletonRepository: TextureRepositoryWrapper, @unchecked Sendable {

    static let shared = TextureUndoInMemorySingletonRepository()

    private init() {
        super.init(repository: TextureLayerInMemoryRepository())
    }
}
