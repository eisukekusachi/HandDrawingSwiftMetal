//
//  HandDrawingCanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/19.
//

import TextureLayerView

final class HandDrawingCanvasViewDependencies {

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    init(
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
