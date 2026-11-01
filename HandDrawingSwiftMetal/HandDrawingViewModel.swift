//
//  Created by Eisuke Kusachi
//

import Combine
import CanvasView
import Core
import FileView
import TextureLayerView
import UIKit

/// Asks the view to reinitialize the canvas after a file action.
struct InitializeCanvasRequest: Equatable {
    /// Whether the layer list UI should reload from `textureLayers`
    let updateLayerList: Bool
    /// Whether the presented file list should be dismissed after initialization
    let dismissFileView: Bool

    init(
        updateLayerList: Bool = false,
        dismissFileView: Bool = false
    ) {
        self.updateLayerList = updateLayerList
        self.dismissFileView = dismissFileView
    }
}

@MainActor
final class HandDrawingViewModel: ObservableObject {

    var textureSize: CGSize {
        undoableTextureLayers.textureSize
    }

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette

    let undoableTextureLayers: TextureLayersUndoableState

    let fileList: FileList
    let thumbnailFileName: String

    /// Current file for displaying in the file list
    func currentFileItem(thumbnail: UIImage?) -> FileItem {
        .init(
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: zipFileURL(projectName: project.currentProjectName)
        )
    }

    func zipFileURL(projectName: String) -> URL {
        documentsDataStore.zipFileURL(
            projectName: projectName,
            suffix: fileList.fileSuffix
        )
    }

    private let textureLayerSnapshotReader: any TextureLayersSnapshotReading
    private let coreDataTextureLayerStorage: CoreDataTextureLayerStorage?
    let projectStorage: CoreDataProjectStorage
    let drawingToolStorage: CoreDataDrawingToolStorage
    let brushPaletteStorage: CoreDataBrushPaletteStorage
    let eraserPaletteStorage: CoreDataEraserPaletteStorage

    private let textureLayersStorageController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )
    private let projectStorageController = PersistenceController(
        xcdatamodeldName: "ProjectStorage"
    )
    private let drawingToolStorageController = PersistenceController(
        xcdatamodeldName: "DrawingToolStorage"
    )

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    var alert: AnyPublisher<any Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    let alertSubject = PassthroughSubject<any Error, Never>()

    var toast: AnyPublisher<ToastMessage, Never> {
        toastSubject.eraseToAnyPublisher()
    }
    let toastSubject = PassthroughSubject<ToastMessage, Never>()

    var initializeCanvasRequest: AnyPublisher<InitializeCanvasRequest, Never> {
        initializeCanvasRequestSubject.eraseToAnyPublisher()
    }
    let initializeCanvasRequestSubject = PassthroughSubject<InitializeCanvasRequest, Never>()

    let documentsDataStore: DocumentsDataStore

    let dependencies: HandDrawingViewDependencies

    private var cancellables = Set<AnyCancellable>()

    init(
        dependencies: HandDrawingViewDependencies,
        fileSuffix: String = "zip",
        thumbnailFileName: String = "thumbnail.png"
    ) {
        self.dependencies = dependencies
        self.fileList = FileList(fileSuffix: fileSuffix)
        self.thumbnailFileName = thumbnailFileName

        self.documentsDataStore = DocumentsDataStore(
            fileManager: dependencies.fileManager
        )

        self.brushPalette = .init()
        self.eraserPalette = .init()

        let undoableTextureLayers = TextureLayersUndoableState(
            repository: dependencies.documentsTextureDataRepository
        )
        self.undoableTextureLayers = undoableTextureLayers
        if let makeTextureLayerStorage = dependencies.textureLayerStorage {
            let reader = makeTextureLayerStorage(undoableTextureLayers)
            self.textureLayerSnapshotReader = reader
            self.coreDataTextureLayerStorage = reader as? CoreDataTextureLayerStorage
        } else {
            let storage = CoreDataTextureLayerStorage(
                textureLayers: undoableTextureLayers,
                context: textureLayersStorageController.viewContext
            )
            self.textureLayerSnapshotReader = storage
            self.coreDataTextureLayerStorage = storage
        }
        self.projectStorage = .init(
            project: project,
            context: projectStorageController.viewContext
        )
        self.drawingToolStorage = .init(
            drawingTool: drawingTool,
            context: drawingToolStorageController.viewContext
        )
        self.brushPaletteStorage = .init(
            palette: brushPalette,
            context: drawingToolStorageController.viewContext
        )
        self.eraserPaletteStorage = .init(
            palette: eraserPalette,
            context: drawingToolStorageController.viewContext
        )

        self.fileList.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func onViewDidLoad(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        undoRegister: TextureLayerUndoRegister,
        canvasView: TextureLayerCanvasView
    ) {
        undoableTextureLayers.setup(
            device: device,
            commandQueue: commandQueue,
            canvasView: canvasView
        )
        undoableTextureLayers.setUndo(undoRegister: undoRegister)

        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }
        Task {
            await setupFileList()
        }
    }

    /// Loads textures from the documents directory.
    func loadTexturesFromDocuments(
        device: MTLDevice,
        fallbackTextureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async throws -> CGSize {
        if let snapshot = textureLayerSnapshotReader.savedLayersSnapshot() {
            do {
                // Load MTLTextures from the documents directory.
                try dependencies.documentsTextureDataRepository.restoreTextures(
                    ids: snapshot.layers.map(\.id),
                    textureSize: snapshot.textureSize,
                    device: device
                )
                undoableTextureLayers.setLayers(snapshot)
                return snapshot.textureSize
            } catch {
                // Pixel files missing or invalid. Discard stale Core Data and fall through to a blank layer.
                textureLayerSnapshotReader.clearSavedLayers()
            }
        }

        try await installBlankLayer(
            textureSize: fallbackTextureSize,
            device: device,
            commandQueue: commandQueue
        )
        return fallbackTextureSize
    }

    /// Creates one default layer with an empty texture file and applies it as the current layer stack.
    func installBlankLayer(
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        // Default single layer.
        let layer = TextureLayerModel(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        // Blank pixel buffer for the layer in the documents directory.
        try await dependencies.documentsTextureDataRepository.initializeTexture(
            id: layer.id,
            textureSize: textureSize,
            device: device,
            commandQueue: commandQueue
        )
        // Replace layer list with this layer and set canvas size.
        undoableTextureLayers.setLayers(
            [layer],
            textureSize: textureSize
        )
    }

    func toggleDrawingTool() {
        drawingTool.swapTool(drawingTool.type)
    }

    func showActivityIndicator(_ isShown: Bool) {
        activityIndicatorSubject.send(isShown)
    }

    func showError(_ error: Error) {
        alertSubject.send(error)
    }

    func showToast(_ model: ToastMessage) {
        toastSubject.send(model)
    }
}

private extension HandDrawingViewModel {

    func fetchDataFromCoreDataIfAvailable() throws {
        if let projectEntity = try projectStorage.fetch() {
            projectStorage.update(projectEntity)
        }
        if let drawingToolEntity = try drawingToolStorage.fetch() {
            drawingToolStorage.update(drawingToolEntity)
        }
        if let brushEntity = try brushPaletteStorage.fetch() {
            brushPaletteStorage.update(brushEntity)
        }
        if let eraserEntity = try eraserPaletteStorage.fetch() {
            eraserPaletteStorage.update(eraserEntity)
        }
    }
}
