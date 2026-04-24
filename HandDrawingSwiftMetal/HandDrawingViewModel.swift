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

    let initializeColors: [UIColor] = [
        .black.withAlphaComponent(0.8),
        .gray.withAlphaComponent(0.8),
        .red.withAlphaComponent(0.8),
        .blue.withAlphaComponent(0.8),
        .green.withAlphaComponent(0.8),
        .yellow.withAlphaComponent(0.8),
        .purple.withAlphaComponent(0.8)
    ]

    let initializeAlphas: [Int] = [
        255,
        225,
        200,
        175,
        150,
        125,
        100,
        50
    ]

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette

    let textureLayersState: TextureLayersState = TextureLayersState()

    private let textureLayerStorage: CoreDataTextureLayerStorage

    private let textureLayersStorageController: PersistenceController = PersistenceController(
        xcdatamodeldName: "TextureLayerStorage"
    )

    var fileSuffix: String { fileCoordinator.fileSuffix }

    var fileList: [LocalFileItem] { fileCoordinator.fileList }

    var projectDocumentURL: URL {
        fileCoordinator.documentURLForProjectName(project.projectName)
    }

    private let fileCoordinator: FileCoordinator

    /// Current file for displaying in the file list
    func currentFile(thumbnail: UIImage?) -> LocalFileItem {
        fileCoordinator.localFileItem(for: project, thumbnail: thumbnail)
    }

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

    init(
        dependencies: HandDrawingViewDependencies? = nil
    ) {
        self.brushPalette = .init(colors: initializeColors)
        self.eraserPalette = .init(alphas: initializeAlphas)
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
        self.fileCoordinator = FileCoordinator(dependencies: dependencies ?? .init())
        self.fileCoordinator.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func loadLocalDrawingComponentsData(configuration: ProjectConfiguration) {
        fileCoordinator.applyProjectFileConfiguration(configuration)

        // Fetch data from Core Data
        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }

        Task {
            await fileCoordinator.refreshFileListFromDocuments()
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
                try fileCoordinator.restorePersistedTextureLayersInDocuments(
                    restoredTextureLayerDataFromCoreData,
                    device: device
                )
                textureLayersData = restoredTextureLayerDataFromCoreData
                resolvedTextureSize = restoredTextureLayerDataFromCoreData.textureSize

            } catch {
                // Initialize using the configuration values when an error occurs
                let newData = await fileCoordinator.createAndInitializeTextureLayers(
                    device: device,
                    textureSize: fallbackTextureSize,
                    commandQueue: commandQueue
                )
                textureLayersData = newData
                resolvedTextureSize = fallbackTextureSize

                // Initialize the Core Data storage if fetching fails
                textureLayerStorage.clearAll()
            }
        } else {
            let newData = await fileCoordinator.createAndInitializeTextureLayers(
                device: device,
                textureSize: fallbackTextureSize,
                commandQueue: commandQueue
            )
            textureLayersData = newData
            resolvedTextureSize = fallbackTextureSize
        }

        textureLayersState.update(textureLayersData)

        return resolvedTextureSize
    }
}

extension HandDrawingViewModel {
    func onSaveFiles(
        thumbnail: UIImage?,
        to workingDirectoryURL: URL
    ) async throws {
        try await fileCoordinator.saveCanvasToWorkingDirectory(
            textureLayersState: textureLayersState,
            thumbnail: thumbnail,
            to: workingDirectoryURL
        )
    }

    func onLoadFiles(
        device: MTLDevice,
        from workingDirectoryURL: URL
    ) async throws {
        try await fileCoordinator.loadCanvasFromWorkingDirectory(
            device: device,
            from: workingDirectoryURL,
            into: textureLayersState
        )
    }

    func onNewCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let data = try await fileCoordinator.createNewTextureLayers(
            device: device,
            textureSize: textureLayersState.textureSize,
            commandQueue: commandQueue
        )
        textureLayersState.update(data)
    }
}

extension HandDrawingViewModel {
    func toggleDrawingTool() {
        drawingTool.swapTool(drawingTool.type)
    }

    func resetCoreData() {
        resetDrawingDefaultsAndSetProjectName(Calendar.currentDate)
    }

    /// Same defaults as `resetCoreData`, but sets the project title to `projectName` (e.g. new file from the file list).
    func resetDrawingDefaultsAndSetProjectName(_ projectName: String) {
        drawingToolStorage.update(
            type: .brush,
            brushDiameter: 8,
            eraserDiameter: 8
        )
        brushPalette.update(
            colors: initializeColors,
            index: 0
        )
        eraserPalette.update(
            alphas: initializeAlphas,
            index: 0
        )
        project.update(
            projectName: projectName,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension HandDrawingViewModel {

    func performSaveCanvas(
        saveCanvasAction: ((URL) async throws -> Void)?,
        zipFileURL: URL
    ) async throws {
        try await fileCoordinator.saveZippedProject(to: zipFileURL) { workingDirectoryURL in
            try await saveCanvasAction?(workingDirectoryURL)
            try self.fileCoordinator.writeSessionMetadataToWorkingDirectory(
                workingDirectoryURL,
                drawingTool: self.drawingTool,
                brushPalette: self.brushPalette,
                eraserPalette: self.eraserPalette,
                project: self.project
            )
        }
    }

    func onSaveCanvas(
        saveCanvasAction: ((URL) async throws -> Void)?,
        completion: (() -> Void)?,
        zipFileURL: URL
    ) {
        Task(priority: .userInitiated) { [weak self] in
            guard let `self` else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.performSaveCanvas(
                    saveCanvasAction: saveCanvasAction,
                    zipFileURL: zipFileURL
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

    /// New blank project file on disk: unique URL, new canvas, default tools, then save and list row.
    func createNewEmptyProjectFile(
        proposedName: String,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        saveCanvasAction: @escaping (URL) async throws -> Void
    ) async throws -> URL {
        activityIndicatorSubject.send(true)
        defer { activityIndicatorSubject.send(false) }

        let targetURL = try fileCoordinator.makeUniqueNewProjectDocumentURL(proposedBaseName: proposedName)
        let stem = targetURL.deletingPathExtension().lastPathComponent
        try await onNewCanvas(device: device, commandQueue: commandQueue)
        resetDrawingDefaultsAndSetProjectName(stem)
        try await performSaveCanvas(
            saveCanvasAction: saveCanvasAction,
            zipFileURL: targetURL
        )
        upsertFileList(currentFile(thumbnail: nil))
        return targetURL
    }

    func onLoadCanvas(
        zipFileURL: URL,
        action: ((URL) async throws -> Void)?,
        completion: (() -> Void)?
    ) {
        Task { [weak self] in
            guard let `self` else { return }

            defer { self.activityIndicatorSubject.send(false) }
            self.activityIndicatorSubject.send(true)

            do {
                try await self.fileCoordinator.loadUnzippedProject(from: zipFileURL) { workingDirectoryURL in
                    try await action?(workingDirectoryURL)

                    try self.projectStorage.update(
                        directoryURL: workingDirectoryURL,
                        projectName: zipFileURL.deletingPathExtension().lastPathComponent
                    )

                    try? self.drawingToolStorage.update(directoryURL: workingDirectoryURL)
                    try? self.brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                    try? self.eraserPaletteStorage.update(directoryURL: workingDirectoryURL)
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
}

extension HandDrawingViewModel {
    func upsertFileList(_ file: LocalFileItem) {
        fileCoordinator.upsertFileList(file)
    }

    @discardableResult
    func renameFileForFileView(
        oldFileURL: URL,
        newName: String,
        currentOpenFileURL: URL
    ) throws -> URL {
        try fileCoordinator.renameFileForFileView(
            oldFileURL: oldFileURL,
            newName: newName,
            currentOpenFileURL: currentOpenFileURL,
            project: project
        )
    }

    func deleteFileForFileView(
        fileURL: URL,
        currentOpenFileURL: URL
    ) throws {
        try fileCoordinator.deleteFileForFileView(
            fileURL: fileURL,
            currentOpenFileURL: currentOpenFileURL
        )
    }
}
