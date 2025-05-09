//
//  DocumentsDirectoryTextureSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Foundation

final class DocumentsDirectoryTextureSingletonRepository: TextureRepositoryWrapper {

    static let shared = DocumentsDirectoryTextureRepository()

    private init() {
        super.init(repository: DocumentsDirectoryTextureRepository())
    }

}
