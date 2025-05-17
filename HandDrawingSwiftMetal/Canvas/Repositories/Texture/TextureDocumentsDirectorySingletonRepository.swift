//
//  TextureDocumentsDirectorySingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Foundation

final class TextureDocumentsDirectorySingletonRepository: TextureRepositoryWrapper {

    static let shared = TextureDocumentsDirectoryRepository()

    private init() {
        super.init(repository: TextureDocumentsDirectoryRepository())
    }

}
