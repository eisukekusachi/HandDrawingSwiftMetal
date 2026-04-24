//
//  HandDrawingViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Combine
import CanvasView
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

    private let textureLayerStorage: CoreDataTextureLayerStorage

    private let textureLayersStorageController: PersistenceController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )

    var fileList: [LocalFileItem] { fileCoordinator.fileList }

    var zipFileURL: URL {
        FileManager.zipFileURL(
            projectName: project.currentProjectName,
            suffix: fileCoordinator.fileSuffix
        )
    }

    /// Current file for displaying in the file list
    func currentFileItem(thumbnail: UIImage?) -> LocalFileItem {
        fileCoordinator.currentFileItem(for: project, thumbnail: thumbnail)
    }

    private let fileCoordinator: FileCoordinator

    private let projectStorage: CoreDataProjectStorage
    private let drawingToolStorage: CoreDataDrawingToolStorage
    private let brushPaletteStorage: CoreDataBrushPaletteStorage
    private let eraserPaletteStorage: CoreDataEraserPaletteStorage

    private let projectStorageController: PersistenceController
    private let drawingToolStorageController: PersistenceController

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    var alert: AnyPublisher<any Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<any Error, Never>()

    var toast: AnyPublisher<ToastMessage, Never> {
        toastSubject.eraseToAnyPublisher()
    }
    private let toastSubject = PassthroughSubject<ToastMessage, Never>()

    private var cancellables = Set<AnyCancellable>()

    private let dependencies: HandDrawingViewDependencies

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
        self.fileCoordinator = FileCoordinator(dependencies: self.dependencies)
        self.fileCoordinator.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func loadLocalDrawingComponentsData(configuration: ProjectConfiguration) {
        // Fetch data from Core Data
        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }
        Task {
            await fileCoordinator.setupFileList(
                configuration: configuration
            )
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
                try fileCoordinator.initializeStorageByRestoring(
                    textureLayers: restoredTextureLayerDataFromCoreData,
                    device: device
                )
                textureLayersData = restoredTextureLayerDataFromCoreData
                resolvedTextureSize = restoredTextureLayerDataFromCoreData.textureSize

            } catch {
                do {
                    let newTextureLayers = TextureLayersModel(textureSize: fallbackTextureSize)

                    // Initialize using the configuration values when an error occurs
                    try await fileCoordinator.initializeStorage(
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

                try await fileCoordinator.initializeStorage(
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
}

extension HandDrawingViewModel {

    func loadCanvas(
        device: MTLDevice?,
        zipFileURL: URL,
        completion: (() -> Void)?
    ) {
        Task { [weak self] in
            guard
                let `self`,
                let device
            else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.fileCoordinator.loadProject(
                    device: device,
                    textureLayersState: textureLayersState,
                    from: zipFileURL
                ) { [weak self] workingDirectoryURL in
                    guard let `self` else { return }
                    try self.projectStorage.update(
                        directoryURL: workingDirectoryURL,
                        projectName: zipFileURL.baseName
                    )
                    try? self.drawingToolStorage.update(directoryURL: workingDirectoryURL)
                    try? self.brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                    try? self.eraserPaletteStorage.update(directoryURL: workingDirectoryURL)
                }

                let textures = try? await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
                    self.textureLayersState.layers.map { $0.id },
                    textureSize: textureLayersState.textureSize,
                    device: device
                )
                textures?.forEach { texture in
                    self.textureLayersState.updateThumbnail(texture.0, texture: texture.1)
                }

                completion?()

                self.toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                self.alertSubject.send(error)
            }
        }
    }

    func saveCanvas(
        thumbnail: UIImage?,
        completion: (() -> Void)?,
        zipFileURL: URL
    ) {
        Task(priority: .userInitiated) { [weak self] in
            guard let `self` else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.fileCoordinator.saveProject(
                    content: .init(
                        thumbnail: thumbnail,
                        textureLayersState: self.textureLayersState,
                        project: self.project,
                        drawingTool: self.drawingTool,
                        brushPalette: self.brushPalette,
                        eraserPalette: self.eraserPalette
                    ),
                    to: zipFileURL
                )

                completion?()

                self.toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                self.alertSubject.send(error)
            }
        }
    }
}

extension HandDrawingViewModel {

    /// New blank project file on disk: unique URL, new canvas, default tools, then save and list row.
    func onTapCreateButton(
        fileName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> URL {
        activityIndicatorSubject.send(true)
        defer { activityIndicatorSubject.send(false) }

        let targetURL = try URL.uniqueProjectURLInDocuments(
            fileName: fileName,
            fileSuffix: fileCoordinator.fileSuffix
        )

        let newTextureLayersState: TextureLayersModel = .init(textureSize: textureLayersState.textureSize)

        try await fileCoordinator.initializeStorage(
            textureLayers: newTextureLayersState,
            device: device,
            commandQueue: commandQueue
        )
        textureLayersState.update(newTextureLayersState)

        drawingToolStorage.initializeData()
        brushPalette.initalizeData()
        eraserPalette.initalizeData()
        project.update(
            projectName: targetURL.baseName,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await fileCoordinator.saveProject(
            content: .init(
                thumbnail: nil,
                textureLayersState: textureLayersState,
                project: project,
                drawingTool: drawingTool,
                brushPalette: brushPalette,
                eraserPalette: eraserPalette
            ),
            to: targetURL
        )

        upsertFileList(
            currentFileItem(thumbnail: nil)
        )

        return targetURL
    }

    @discardableResult
    func onTapRenameButton(
        oldFileURL: URL,
        newName: String,
        currentOpenFileURL: URL
    ) throws -> URL {
        let newURL = try fileCoordinator.renameFile(
            oldFileURL: oldFileURL,
            newName: newName,
            currentOpenFileURL: currentOpenFileURL,
            project: project
        )

        if oldFileURL == currentOpenFileURL {
            project.update(
                projectName: newURL.baseName,
                updatedAt: Date()
            )
        }

        return newURL
    }

    func onTapDeleteButton(
        fileURL: URL,
        currentOpenFileURL: URL
    ) throws {
        try fileCoordinator.deleteFile(
            fileURL: fileURL,
            currentOpenFileURL: currentOpenFileURL
        )
    }

    func upsertFileList(_ file: LocalFileItem) {
        fileCoordinator.upsertFileList(file)
    }
}
