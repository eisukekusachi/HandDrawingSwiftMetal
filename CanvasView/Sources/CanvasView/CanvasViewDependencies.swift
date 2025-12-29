//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {
    /// Repository that manages canvas layer textures, persisting them on disk so the canvas can be restored after the app is closed
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepository

    /// Repository that manages textures used for undo in memory
    let undoTextureRepository: TextureInMemoryRepository?

    /// Used to render or copy textures
    let renderer: MTLRendering

    /// A view for displaying the texture
    let displayView: CanvasDisplayable
}

extension CanvasViewDependencies {
    init(
        renderer: MTLRendering,
        displayView: CanvasDisplayable
    ) {
        self.textureLayersDocumentsRepository = .init(
            storageDirectoryURL: URL.applicationSupport,
            directoryName: "TextureStorage",
            renderer: renderer
        )

        self.undoTextureRepository = TextureInMemoryRepository(
            renderer: renderer
        )

        self.renderer = renderer

        self.displayView = displayView
    }
}
