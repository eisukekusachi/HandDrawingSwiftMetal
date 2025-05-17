//
//  TextureLayerInMemorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

final class TextureLayerInMemorySingletonRepository: TextureLayerRepositoryWrapper {

    static let shared = TextureLayerInMemorySingletonRepository()

    private init() {
        super.init(repository: TextureLayerInMemoryRepository())
    }

}
