//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {
    /// A repository that manages canvas layer textures, persisting them on disk so the canvas can be restored after the app is closed
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepository

    /// A repository that manages textures used for undo in memory
    let undoTextureRepository: UndoTextureInMemoryRepository?

    /// A protocol responsible for rendering textures to a drawable surface
    let renderer: MTLRendering

    /// A protocol representing a drawable surface for the canvas
    let displayView: CanvasDisplayable?
}
