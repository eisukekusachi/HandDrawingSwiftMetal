//
//  DocumentsFolderTextureSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/04.
//

import Foundation

final class DocumentsFolderTextureSingletonRepository: TextureRepositoryWrapper {

    static let shared = DocumentsFolderTextureRepository()

    private init() {
        super.init(repository: DocumentsFolderTextureRepository())
    }

}
