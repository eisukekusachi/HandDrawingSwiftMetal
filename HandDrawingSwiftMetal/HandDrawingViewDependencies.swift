//
//  Created by Eisuke Kusachi
//

import Core
import Foundation
import TextureLayerView

@MainActor
final class HandDrawingViewDependencies {

    let fileManager: FileManaging

    /// Zip-based project file I/O in Documents (save, open, delete, rename).
    let documentsProjectFileStorage: DocumentsProjectFileStorage

    /// Local on-disk texture cache (Application Support). Kept so it remains after the app terminates.
    let localTextureFileRepository: MTLTextureDataRepositoryProtocol

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

    private let projectCoreDataStorage: CoreDataStorage
    private let textureLayersCoreDataStorage: CoreDataStorage
    private let drawingToolCoreDataStorage: CoreDataStorage

    init(
        fileManager: FileManaging? = nil,
        documentsProjectFileStorage: DocumentsProjectFileStorage? = nil,
        localTextureFileRepository: MTLTextureDataRepositoryProtocol? = nil,
        textureRepository: MTLTextureRepositoryProtocol? = nil,
        projectCoreDataStorage: CoreDataStorage = CoreDataStorage(xcdatamodeldName: "ProjectStorage"),
        textureLayersCoreDataStorage: CoreDataStorage = CoreDataStorage(xcdatamodeldName: "TextureLayerStorage"),
        drawingToolCoreDataStorage: CoreDataStorage = CoreDataStorage(xcdatamodeldName: "DrawingToolStorage")
    ) {
        self.fileManager = fileManager ?? FileManagerWrapper()
        self.documentsProjectFileStorage = documentsProjectFileStorage ?? DocumentsProjectFileStorage(
            fileManager: self.fileManager
        )
        // `shared` is `@MainActor` / actor-isolated; default arguments are evaluated in a nonisolated context,
        // so defaults are applied here instead of in the parameter list.
        self.localTextureFileRepository = localTextureFileRepository ?? LocalTextureFileRepository.shared
        self.inMemoryTextureRepository = textureRepository ?? InMemoryTextureRepository.shared

        self.projectCoreDataStorage = projectCoreDataStorage
        self.textureLayersCoreDataStorage = textureLayersCoreDataStorage
        self.drawingToolCoreDataStorage = drawingToolCoreDataStorage
        let drawingToolContext = drawingToolCoreDataStorage.viewContext

        self.projectStorage = CoreDataProjectStorage(context: projectCoreDataStorage.viewContext)
        self.textureLayerStorage = CoreDataTextureLayerStorage(context: textureLayersCoreDataStorage.viewContext)
        self.drawingToolStorage = CoreDataDrawingToolStorage(context: drawingToolContext)
        self.brushPaletteStorage = CoreDataBrushPaletteStorage(context: drawingToolContext)
        self.eraserPaletteStorage = CoreDataEraserPaletteStorage(context: drawingToolContext)
    }
}
