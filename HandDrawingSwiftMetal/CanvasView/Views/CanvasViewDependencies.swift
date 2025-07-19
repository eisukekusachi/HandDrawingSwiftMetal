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
    let localFileRepository: LocalFileRepository = LocalFileSingletonRepository.shared.repository
}

extension CanvasViewDependencies {
    init(configuration: CanvasConfiguration) {
        switch configuration.textureLayerRepository {
        case .disk: textureLayerRepository = TextureLayerDocumentsDirectorySingletonRepository.shared
        case .memory: textureLayerRepository = TextureLayerInMemorySingletonRepository.shared
        }

        if let undoRepository = configuration.undoTextureRepository {
            switch undoRepository {
            case .disk: undoTextureRepository = TextureUndoDocumentsDirectorySingletonRepository.shared
            case .memory: undoTextureRepository = TextureUndoInMemorySingletonRepository.shared
            }
        } else {
            undoTextureRepository = nil
        }
    }
}
