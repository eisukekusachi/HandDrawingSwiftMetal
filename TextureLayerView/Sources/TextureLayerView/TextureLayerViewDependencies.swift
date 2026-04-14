//
//  TextureLayerViewDependencies.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/11.
//

import Foundation

final class TextureLayerViewDependencies {

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    init(
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
