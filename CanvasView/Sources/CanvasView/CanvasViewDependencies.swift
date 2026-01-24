//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {

    /// A class that manages drawing on the canvas
    let canvasRenderer: CanvasRenderer

    /// A class that manages texture layers
    let textureLayers: UndoTextureLayers

    /// A Protocol that manages canvas layer textures, persisting them on disk so the canvas can be restored after the app is closed
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    /// A repository that manages textures used for undo in memory
    let undoTextureInMemoryRepository: UndoTextureInMemoryRepository?

    init(
        canvasRenderer: CanvasRenderer,
        textureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol,
        undoTextureInMemoryRepository: UndoTextureInMemoryRepository? = nil
    ) {
        self.canvasRenderer = canvasRenderer
        self.textureLayers = textureLayers
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository
        self.undoTextureInMemoryRepository = undoTextureInMemoryRepository
    }
}
