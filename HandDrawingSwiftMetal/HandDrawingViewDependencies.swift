//
//  Created by Eisuke Kusachi
//

import Core
import Foundation
import TextureLayerView

@MainActor
final class HandDrawingViewDependencies {

    /// File operations for project zip files in the Documents directory.
    let fileManager: FileManaging

    /// Repository for texture data. Kept on disk so it remains after the app terminates.
    let documentsTextureDataRepository: MTLTextureDataRepositoryProtocol

    /// Repository for undo textures. Kept in memory because undo needs fast access.
    let inMemoryTextureRepository: MTLTextureRepositoryProtocol

    let textureLayerStorage: CoreDataTextureLayerStorage
    let projectStorage: CoreDataProjectStorage
    let drawingToolStorage: CoreDataDrawingToolStorage
    let brushPaletteStorage: CoreDataBrushPaletteStorage
    let eraserPaletteStorage: CoreDataEraserPaletteStorage

    /// Keeps SQLite stores alive when using the default Core Data stack.
    private let textureLayersStorageController: PersistenceController?
    private let projectStorageController: PersistenceController?
    private let drawingToolStorageController: PersistenceController?

    init(
        fileManager: FileManaging? = nil,
        textureDataRepository: MTLTextureDataRepositoryProtocol? = nil,
        textureRepository: MTLTextureRepositoryProtocol? = nil,
        textureLayerStorage: CoreDataTextureLayerStorage? = nil,
        projectStorage: CoreDataProjectStorage? = nil,
        drawingToolStorage: CoreDataDrawingToolStorage? = nil,
        brushPaletteStorage: CoreDataBrushPaletteStorage? = nil,
        eraserPaletteStorage: CoreDataEraserPaletteStorage? = nil
    ) {
        self.fileManager = fileManager ?? FileManagerWrapper()
        self.documentsTextureDataRepository = textureDataRepository ?? DocumentsTextureDataRepository.shared
        self.inMemoryTextureRepository = textureRepository ?? InMemoryTextureRepository.shared

        if let textureLayerStorage {
            self.textureLayersStorageController = nil
            self.textureLayerStorage = textureLayerStorage
        } else {
            let controller = PersistenceController(xcdatamodeldName: "TextureLayerStorage")
            self.textureLayersStorageController = controller
            self.textureLayerStorage = .init(context: controller.viewContext)
        }

        if let projectStorage {
            self.projectStorageController = nil
            self.projectStorage = projectStorage
        } else {
            let controller = PersistenceController(xcdatamodeldName: "ProjectStorage")
            self.projectStorageController = controller
            self.projectStorage = .init(context: controller.viewContext)
        }

        if
            let drawingToolStorage,
            let brushPaletteStorage,
            let eraserPaletteStorage
        {
            self.drawingToolStorageController = nil
            self.drawingToolStorage = drawingToolStorage
            self.brushPaletteStorage = brushPaletteStorage
            self.eraserPaletteStorage = eraserPaletteStorage
        } else {
            let controller = PersistenceController(xcdatamodeldName: "DrawingToolStorage")
            self.drawingToolStorageController = controller
            let context = controller.viewContext
            self.drawingToolStorage = drawingToolStorage ?? .init(context: context)
            self.brushPaletteStorage = brushPaletteStorage ?? .init(context: context)
            self.eraserPaletteStorage = eraserPaletteStorage ?? .init(context: context)
        }
    }
}
