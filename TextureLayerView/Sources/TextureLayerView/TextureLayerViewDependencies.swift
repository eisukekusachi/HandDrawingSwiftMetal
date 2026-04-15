//
//  TextureLayerViewDependencies.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/11.
//

import Foundation

public final class TextureLayerViewDependencies {

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    public init(
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
