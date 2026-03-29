//
//  HandDrawingCanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/19.
//

import TextureLayerView

@MainActor
final class HandDrawingCanvasViewDependencies {

    let undoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    init() {
        undoTextureInMemoryRepository = UndoTextureInMemoryRepository.shared
        textureLayersDocumentsRepository = TextureLayersDocumentsRepository.shared
    }
}
