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
    let textureRepository: TextureDocumentsDirectoryRepository

    /// Repository that manages textures used for undo in memory
    let undoTextureRepository: TextureInMemoryRepository?

    let displayView: CanvasDisplayable
}

extension CanvasViewDependencies {
    init(
        renderer: MTLRendering,
        displayView: CanvasDisplayable
    ) {
        self.textureRepository = TextureDocumentsDirectoryRepository(
            storageDirectoryURL: URL.applicationSupport,
            directoryName: "TextureStorage",
            renderer: renderer
        )

        self.undoTextureRepository = TextureInMemoryRepository(
            renderer: renderer
        )

        self.displayView = displayView
    }
}
