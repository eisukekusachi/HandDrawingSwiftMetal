//
//  HandDrawingCanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/19.
//

import TextureLayerView

@MainActor
public final class HandDrawingCanvasViewDependencies {

    public let undoTextureInMemoryRepository: UndoTextureInMemoryRepositoryProtocol

    public let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    public init() {
        undoTextureInMemoryRepository = UndoTextureInMemoryRepository.shared
        textureLayersDocumentsRepository = TextureLayersDocumentsRepository.shared
    }
}
