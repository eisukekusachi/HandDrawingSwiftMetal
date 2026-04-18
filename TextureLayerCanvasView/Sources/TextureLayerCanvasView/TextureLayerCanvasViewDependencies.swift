//
//  TextureLayerCanvasViewDependencies.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/18.
//

import TextureLayerView

final class TextureLayerCanvasViewDependencies {

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    init(
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
