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

    /// Project metadata saved in Core Data.
    let projectStorage: CoreDataProjectStorage

    /// Layer list metadata saved in Core Data.
    let textureLayerStorage: CoreDataTextureLayerStorage

    /// Drawing tool settings saved in Core Data.
    let drawingToolStorage: CoreDataDrawingToolStorage

    /// Brush palette saved in Core Data.
    let brushPaletteStorage: CoreDataBrushPaletteStorage

    /// Eraser palette saved in Core Data.
    let eraserPaletteStorage: CoreDataEraserPaletteStorage

    /// Keeps SQLite stores alive when using the default Core Data stack.
    private let textureLayersStorageController: PersistenceController?
    private let projectStorageController: PersistenceController?
    private let drawingToolStorageController: PersistenceController?

    init(
        fileManager: FileManaging? = nil,
        textureDataRepository: MTLTextureDataRepositoryProtocol? = nil,
        textureRepository: MTLTextureRepositoryProtocol? = nil,
        projectStorage: CoreDataProjectStorage? = nil,
        textureLayerStorage: CoreDataTextureLayerStorage? = nil,
        drawingToolStorage: CoreDataDrawingToolStorage? = nil,
        brushPaletteStorage: CoreDataBrushPaletteStorage? = nil,
        eraserPaletteStorage: CoreDataEraserPaletteStorage? = nil
    ) {
        self.fileManager = fileManager ?? FileManagerWrapper()
        self.documentsTextureDataRepository = textureDataRepository ?? DocumentsTextureDataRepository.shared
        self.inMemoryTextureRepository = textureRepository ?? InMemoryTextureRepository.shared

        // Project metadata saved in Core Data.
        if projectStorage == nil {
            let controller = PersistenceController(
                xcdatamodeldName: "ProjectStorage"
            )
            self.projectStorageController = controller
            self.projectStorage = .init(context: controller.viewContext)
        } else {
            self.projectStorageController = nil
            self.projectStorage = projectStorage!
        }

        // Layer list metadata saved in Core Data.
        if textureLayerStorage == nil {
            let controller = PersistenceController(
                xcdatamodeldName: "TextureLayerStorage"
            )
            self.textureLayersStorageController = controller
            self.textureLayerStorage = .init(context: controller.viewContext)
        } else {
            self.textureLayersStorageController = nil
            self.textureLayerStorage = textureLayerStorage!
        }

        // Drawing tool settings saved in Core Data.
        if drawingToolStorage == nil || brushPaletteStorage == nil || eraserPaletteStorage == nil {
            let controller = PersistenceController(
                xcdatamodeldName: "DrawingToolStorage"
            )
            self.drawingToolStorageController = controller
            let context = controller.viewContext
            self.drawingToolStorage = drawingToolStorage ?? .init(context: context)
            self.brushPaletteStorage = brushPaletteStorage ?? .init(context: context)
            self.eraserPaletteStorage = eraserPaletteStorage ?? .init(context: context)
        } else {
            self.drawingToolStorageController = nil
            self.drawingToolStorage = drawingToolStorage!
            self.brushPaletteStorage = brushPaletteStorage!
            self.eraserPaletteStorage = eraserPaletteStorage!
        }
    }
}
