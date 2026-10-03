//
//  HandDrawingViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Combine
import CanvasView
import Core
import FileView
import TextureLayerCanvasView
import TextureLayerView
import UIKit

/// Asks the view to reinitialize the canvas after a file action.
struct InitializeCanvasRequest: Equatable {
    /// Whether the layer list UI should reload from `textureLayersState`
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
        textureLayersState.textureSize
    }

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette

    let textureLayersState: TextureLayersState

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

    private let textureLayerStorage: CoreDataTextureLayerStorage
    let projectStorage: CoreDataProjectStorage
    let drawingToolStorage: CoreDataDrawingToolStorage
    let brushPaletteStorage: CoreDataBrushPaletteStorage
    let eraserPaletteStorage: CoreDataEraserPaletteStorage

    private let textureLayersStorageController: PersistenceController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )
    private let projectStorageController: PersistenceController
    private let drawingToolStorageController: PersistenceController

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
            fileManager: dependencies.fileManager,
            localFileRepository: dependencies.localFileRepository
        )

        self.brushPalette = .init()
        self.eraserPalette = .init()

        self.textureLayersState = TextureLayersState(
            repository: dependencies.textureLayersDocumentsRepository
        )
        self.textureLayerStorage = .init(
            textureLayersState: self.textureLayersState,
            context: textureLayersStorageController.viewContext
        )
        self.projectStorageController = .init(
            xcdatamodeldName: "ProjectStorage"
        )
        self.drawingToolStorageController = PersistenceController(
            xcdatamodeldName: "DrawingToolStorage"
        )
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
        undo: UndoTextureLayerRegistrar,
        canvasView: TextureLayerCanvasView
    ) {
        textureLayersState.setup(
            device: device,
            commandQueue: commandQueue,
            undo: undo,
            canvasView: canvasView,
            showError: { [weak self] error in
                self?.showError(error)
            }
        )

        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }
        Task {
            await setupFileList()
        }
    }

    func prepareTextureLayers(
        device: MTLDevice,
        fallbackTextureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> CGSize {
        if let restoredTextureLayerDataFromCoreData {
            do {
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    ids: restoredTextureLayerDataFromCoreData.layers.map(\.id),
                    textureSize: restoredTextureLayerDataFromCoreData.textureSize,
                    device: device
                )
                textureLayersState.update(restoredTextureLayerDataFromCoreData)
                return restoredTextureLayerDataFromCoreData.textureSize
            } catch {
                let textureSize = await installBlankLayerOrAbort(
                    textureSize: fallbackTextureSize,
                    device: device,
                    commandQueue: commandQueue
                )
                textureLayerStorage.clearAll()
                return textureSize
            }
        }

        return await installBlankLayerOrAbort(
            textureSize: fallbackTextureSize,
            device: device,
            commandQueue: commandQueue
        )
    }

    func installBlankLayer(
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let layer = TextureLayerModel(
            id: LayerId(),
            title: TimeStampFormatter.currentDate,
            alpha: 255,
            isVisible: true
        )
        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            id: layer.id,
            textureSize: textureSize,
            device: device,
            commandQueue: commandQueue
        )
        textureLayersState.setLayers(
            [layer],
            textureSize: textureSize
        )
    }

    private func installBlankLayerOrAbort(
        textureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async -> CGSize {
        do {
            try await installBlankLayer(
                textureSize: textureSize,
                device: device,
                commandQueue: commandQueue
            )
            return textureSize
        } catch {
            fatalError("Failed to initialize storage")
        }
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

    var restoredTextureLayerDataFromCoreData: TextureLayersSnapshot? {
        guard
            let entity = textureLayerStorage.fetch()
        else { return nil }
        return textureLayerStorage.textureLayersSnapshot(from: entity)
    }

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
