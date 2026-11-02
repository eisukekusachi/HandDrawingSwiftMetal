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

    /// Persisted project metadata.
    let projectStorage: CoreDataProjectStorage

    /// Persisted layer list metadata.
    let textureLayerStorage: CoreDataTextureLayerStorage

    /// Persisted drawing tool settings.
    let drawingToolStorage: CoreDataDrawingToolStorage

    /// Persisted brush palette.
    let brushPaletteStorage: CoreDataBrushPaletteStorage

    /// Persisted eraser palette.
    let eraserPaletteStorage: CoreDataEraserPaletteStorage

    /// Keeps SQLite stores alive when using the default Core Data stack.
    private let textureLayersCoreDataStorage: CoreDataStorage?
    private let projectCoreDataStorage: CoreDataStorage?
    private let drawingToolCoreDataStorage: CoreDataStorage?

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

        // Default persisted project metadata.
        if projectStorage == nil {
            let coreDataStorage = CoreDataStorage(xcdatamodeldName: "ProjectStorage")
            self.projectCoreDataStorage = coreDataStorage
            self.projectStorage = .init(context: coreDataStorage.viewContext)
        } else {
            self.projectCoreDataStorage = nil
            self.projectStorage = projectStorage!
        }

        // Default persisted layer list metadata.
        if textureLayerStorage == nil {
            let coreDataStorage = CoreDataStorage(xcdatamodeldName: "TextureLayerStorage")
            self.textureLayersCoreDataStorage = coreDataStorage
            self.textureLayerStorage = .init(context: coreDataStorage.viewContext)
        } else {
            self.textureLayersCoreDataStorage = nil
            self.textureLayerStorage = textureLayerStorage!
        }

        // Default persisted drawing tool settings, brush palette, and eraser palette.
        if drawingToolStorage == nil || brushPaletteStorage == nil || eraserPaletteStorage == nil {
            let coreDataStorage = CoreDataStorage(xcdatamodeldName: "DrawingToolStorage")
            self.drawingToolCoreDataStorage = coreDataStorage
            let context = coreDataStorage.viewContext
            self.drawingToolStorage = drawingToolStorage ?? .init(context: context)
            self.brushPaletteStorage = brushPaletteStorage ?? .init(context: context)
            self.eraserPaletteStorage = eraserPaletteStorage ?? .init(context: context)
        } else {
            self.drawingToolCoreDataStorage = nil
            self.drawingToolStorage = drawingToolStorage!
            self.brushPaletteStorage = brushPaletteStorage!
            self.eraserPaletteStorage = eraserPaletteStorage!
        }
    }
}
