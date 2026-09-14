//
//  HandDrawingViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Combine
import CanvasView
import FileView
import UIKit
import TextureLayerView

@MainActor
final class HandDrawingViewModel: ObservableObject {

    var textureSize: CGSize {
        textureLayersState.textureSize
    }

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette

    let textureLayersState: TextureLayersState = TextureLayersState()

    let fileList = FileList(fileSuffix: "zip")

    let thumbnailFileName = "thumbnail.png"

    /// Current file for displaying in the file list
    func currentFileItem(thumbnail: UIImage?) -> FileItem {
        .init(
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: zipFileURL
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

    private var cancellables = Set<AnyCancellable>()

    let dependencies: HandDrawingViewDependencies

    init(
        dependencies: HandDrawingViewDependencies? = nil
    ) {
        self.brushPalette = .init()
        self.eraserPalette = .init()
        self.textureLayerStorage = .init(
            textureLayers: textureLayersState,
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
        self.dependencies = dependencies ?? .init()
        self.fileList.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func loadLocalDrawingComponentsData(configuration _: ProjectConfiguration) {
        // Fetch data from Core Data
        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }
        Task {
            await setupFileList()
        }
    }

    private func fetchDataFromCoreDataIfAvailable() throws {
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

    private var restoredTextureLayerDataFromCoreData: TextureLayersModel? {
        guard
            let entity = textureLayerStorage.fetch()
        else { return nil }
        return textureLayerStorage.textureLayersModel(from: entity)
    }

    func restoreOrInitializeTextureLayers(
        device: MTLDevice,
        fallbackTextureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> CGSize {
        let textureLayersData: TextureLayersModel
        let resolvedTextureSize: CGSize

        if let restoredTextureLayerDataFromCoreData {
            do {
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    textureLayers: restoredTextureLayerDataFromCoreData,
                    device: device
                )
                textureLayersData = restoredTextureLayerDataFromCoreData
                resolvedTextureSize = restoredTextureLayerDataFromCoreData.textureSize

            } catch {
                do {
                    let newTextureLayers = TextureLayersModel(textureSize: fallbackTextureSize)

                    // Initialize using the configuration values when an error occurs
                    try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                        textureLayers: newTextureLayers,
                        device: device,
                        commandQueue: commandQueue
                    )
                    textureLayersData = newTextureLayers
                    resolvedTextureSize = fallbackTextureSize

                    // Initialize the Core Data storage if fetching fails
                    textureLayerStorage.clearAll()
                } catch {
                    fatalError("Failed to initialize storage")
                }
            }
        } else {
            do {
                let newTextureLayers = TextureLayersModel(textureSize: fallbackTextureSize)

                try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                    textureLayers: newTextureLayers,
                    device: device,
                    commandQueue: commandQueue
                )
                textureLayersData = newTextureLayers
                resolvedTextureSize = fallbackTextureSize
            } catch {
                fatalError("Failed to initialize storage")
            }
        }

        textureLayersState.update(textureLayersData)

        return resolvedTextureSize
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
}
