//
//  HandDrawingCanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/19.
//

import TextureLayerView

final class HandDrawingCanvasViewDependencies {

    let undoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol

    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    @MainActor
    init(
        undoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol? = nil,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol? = nil
    ) {
        self.undoTextureInMemoryRepository = undoTextureInMemoryRepository ?? UndoTextureInMemoryRepository.shared
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository ?? TextureLayersDocumentsRepository.shared
    }
}
