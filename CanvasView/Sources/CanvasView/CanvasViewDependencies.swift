//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

struct CanvasViewDependencies {
    /// Repository that manages textures for canvas layers
    let textureRepository: TextureRepository

    /// Repository that manages textures used for undo
    // let undoTextureRepository: TextureRepository?

    /// Repository that manages files in the Documents directory
    let localFileRepository: LocalFileRepository
}

extension CanvasViewDependencies {
    init(
        environmentConfiguration: CanvasEnvironmentConfiguration
    ) {
        switch environmentConfiguration.textureRepositoryType {
        case .disk: textureRepository = TextureDocumentsDirectoryRepository(
            storageDirectoryURL: URL.applicationSupport,
            directoryName: "TextureStorage"
        )
        case .memory: textureRepository = TextureInMemoryRepository()
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
    }
}
