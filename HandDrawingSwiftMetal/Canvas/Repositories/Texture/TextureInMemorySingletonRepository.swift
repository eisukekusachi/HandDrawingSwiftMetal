//
//  TextureInMemorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Foundation

final class TextureInMemorySingletonRepository: TextureRepositoryWrapper {

    static let shared = TextureInMemorySingletonRepository()

    private init() {
        super.init(repository: TextureInMemoryRepository())
    }

}
