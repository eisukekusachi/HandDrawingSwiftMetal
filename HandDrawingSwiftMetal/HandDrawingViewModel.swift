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

    private var textureLayerStorage: CoreDataTextureLayerStorage {
        dependencies.textureLayerStorage
    }

    var projectStorage: CoreDataProjectStorage {
        dependencies.projectStorage
    }

    var drawingToolStorage: CoreDataDrawingToolStorage {
        dependencies.drawingToolStorage
    }

    var brushPaletteStorage: CoreDataBrushPaletteStorage {
        dependencies.brushPaletteStorage
    }

    var eraserPaletteStorage: CoreDataEraserPaletteStorage {
        dependencies.eraserPaletteStorage
    }

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
        self.thumbnailFileName = thumbnailFileName
        self.fileList = .init(fileSuffix: fileSuffix)
        self.documentsDataStore = .init(fileManager: dependencies.fileManager)
        self.undoableTextureLayers = .init(repository: dependencies.documentsTextureDataRepository)
        self.brushPalette = .init()
        self.eraserPalette = .init()

        self.fileList.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        bindCoreDataPersistence()
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

    func loadTexturesFromDocuments(
        device: MTLDevice,
        fallbackTextureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async throws -> CGSize {
        if let entity = try? textureLayerStorage.fetch() {
            let snapshot = TextureLayersSnapshot(entity: entity)
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
                try? textureLayerStorage.clearAll()
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

// MARK: - Core Data

private extension HandDrawingViewModel {

    /// Subscribes to domain model changes and debounces writes to `CoreData*Storage`.
    func bindCoreDataPersistence() {
        let debounce = coreDataSaveDebounceMilliseconds

        // Texture layer metadata (`TextureLayerStorage`).
        Publishers.Merge3(
            undoableTextureLayers.$layerModels.map { _ in () }.eraseToAnyPublisher(),
            undoableTextureLayers.$selectedLayerId.map { _ in () }.eraseToAnyPublisher(),
            undoableTextureLayers.$textureSize.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.textureLayerStorage.save(from: self.undoableTextureLayers) }
        }
        .store(in: &cancellables)

        // Project metadata (`ProjectStorage`).
        Publishers.Merge3(
            project.$currentProjectName.map { _ in () }.eraseToAnyPublisher(),
            project.$updatedAt.map { _ in () }.eraseToAnyPublisher(),
            project.$createdAt.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.projectStorage.save(from: self.project) }
        }
        .store(in: &cancellables)

        // Drawing tool settings (`DrawingToolStorage`).
        Publishers.Merge3(
            drawingTool.$brushDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$eraserDiameter.map { _ in () }.eraseToAnyPublisher(),
            drawingTool.$type.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.drawingToolStorage.save(from: self.drawingTool) }
        }
        .store(in: &cancellables)

        // Brush palette (`DrawingToolStorage` model).
        Publishers.Merge(
            brushPalette.$selectedIndex.map { _ in () }.eraseToAnyPublisher(),
            brushPalette.$items.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.brushPaletteStorage.save(from: self.brushPalette) }
        }
        .store(in: &cancellables)

        // Eraser palette (`DrawingToolStorage` model).
        Publishers.Merge(
            eraserPalette.$selectedIndex.map { _ in () }.eraseToAnyPublisher(),
            eraserPalette.$items.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task { await self.eraserPaletteStorage.save(from: self.eraserPalette) }
        }
        .store(in: &cancellables)
    }

    /// Restores domain models from Core Data when the canvas loads.
    func fetchDataFromCoreDataIfAvailable() throws {
        if let projectEntity = try projectStorage.fetch() {
            project.apply(projectEntity)
        }
        if let drawingToolEntity = try drawingToolStorage.fetch() {
            drawingTool.apply(drawingToolEntity)
        }
        if let brushEntity = try brushPaletteStorage.fetch() {
            brushPalette.apply(brushEntity)
        }
        if let eraserEntity = try eraserPaletteStorage.fetch() {
            eraserPalette.apply(eraserEntity)
        }
    }
}
