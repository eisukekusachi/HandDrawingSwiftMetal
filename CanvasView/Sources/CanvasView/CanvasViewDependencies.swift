//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {
    /// Repository that manages textures for canvas layers
    let textureRepository: TextureRepository

    /// Repository that manages textures used for undo
    // let undoTextureRepository: TextureRepository?

    /// Repository that manages files in the Documents directory
    let localFileRepository: LocalFileRepository

    let renderer: MTLRendering

    let displayView: CanvasDisplayable
}

extension CanvasViewDependencies {
    init(
        environmentConfiguration: CanvasEnvironmentConfiguration,
        renderer: MTLRendering,
        displayView: CanvasDisplayable
    ) {
        switch environmentConfiguration.textureRepositoryType {
        case .disk: textureRepository = TextureDocumentsDirectoryRepository(
            storageDirectoryURL: URL.applicationSupport,
            directoryName: "TextureStorage",
            renderer: renderer
        )
        case .memory: textureRepository = TextureInMemoryRepository(renderer: renderer)
        }

        /*
        if let undoRepository = environmentConfiguration.undoTextureRepositoryType {
            switch undoRepository {
            case .disk: undoTextureRepository = TextureDocumentsDirectoryRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "UndoStorage"
            )
            case .memory: undoTextureRepository = TextureInMemoryRepository()
            }
        } else {
            undoTextureRepository = nil
        }
        */

        localFileRepository = DefaultLocalFileRepository(
            workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
        )

        self.renderer = renderer

        self.displayView = displayView
    }
}
