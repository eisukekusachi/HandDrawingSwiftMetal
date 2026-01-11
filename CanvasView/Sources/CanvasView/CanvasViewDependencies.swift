//
//  CanvasViewDependencies.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/19.
//

import Foundation

@MainActor
struct CanvasViewDependencies {

    let canvasRenderer: CanvasRenderer

    let textureLayers: UndoTextureLayers

    /// A Protocol that manages canvas layer textures, persisting them on disk so the canvas can be restored after the app is closed
    let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    /// A repository that manages textures used for undo in memory
    let undoTextureInMemoryRepository: UndoTextureInMemoryRepository?

    let persistenceController: PersistenceController

    /// Metadata stored in Core Data
    let projectMetaDataStorage: CoreDataProjectMetaDataStorage

    init(
        canvasRenderer: CanvasRenderer,
        textureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol,
        undoTextureInMemoryRepository: UndoTextureInMemoryRepository? = nil,
        persistenceController: PersistenceController,
        projectMetaDataStorage: CoreDataProjectMetaDataStorage
    ) {
        self.canvasRenderer = canvasRenderer
        self.textureLayers = textureLayers
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository
        self.undoTextureInMemoryRepository = undoTextureInMemoryRepository
        self.persistenceController = persistenceController
        self.projectMetaDataStorage = projectMetaDataStorage
    }
}
