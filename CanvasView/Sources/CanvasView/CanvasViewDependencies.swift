//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

struct CanvasViewDependencies {
    /// Repository that manages textures for canvas layers
    let textureLayerRepository: TextureLayerRepository

    /// Repository that manages textures used for undo
    let undoTextureRepository: TextureRepository?

    /// Repository that manages files in the Documents directory
    let localFileRepository: LocalFileRepository
}

extension CanvasViewDependencies {
    init(
        configuration: CanvasConfiguration,
        environmentConfiguration: CanvasEnvironmentConfiguration
    ) {
        switch environmentConfiguration.textureLayerRepositoryType {
        case .disk: textureLayerRepository = TextureLayerDocumentsDirectoryRepository(
            storageDirectoryURL: URL.applicationSupport,
            directoryName: "TextureStorage"
        )
        case .memory: textureLayerRepository = TextureLayerInMemoryRepository()
        }

        if let undoRepository = environmentConfiguration.undoTextureRepositoryType {
            switch undoRepository {
            case .disk: undoTextureRepository = TextureDocumentsDirectoryRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "UndoStorage"
            )
            case .memory: undoTextureRepository = TextureLayerInMemoryRepository()
            }
        } else {
            undoTextureRepository = nil
        }

        localFileRepository = LocalFileRepository(
            workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    }
}
