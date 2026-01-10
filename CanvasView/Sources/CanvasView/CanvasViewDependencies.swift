//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {
    /// A Protocol that manages canvas layer textures, persisting them on disk so the canvas can be restored after the app is closed
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    /// A repository that manages textures used for undo in memory
    let undoTextureRepository: UndoTextureInMemoryRepository?

    init(
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol,
        undoTextureRepository: UndoTextureInMemoryRepository? = nil
    ) {
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository
        self.undoTextureRepository = undoTextureRepository
    }
}
