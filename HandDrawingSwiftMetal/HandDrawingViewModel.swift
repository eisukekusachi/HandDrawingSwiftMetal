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

    var fileSuffix: String {
        _fileSuffix
    }
    private var _fileSuffix: String = ""

    var fileList: [LocalFileItem] {
        _fileList
    }
    private var _fileList: [LocalFileItem] = []

    private let thumbnailName: String = "thumbnail.png"

    /// Current file for displaying in the file list
    func currentFile(thumbnail: UIImage?) -> LocalFileItem {
        .init(
            title: project.projectName,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: URL.documents.appendingPathComponent(
                projectFileName()
            )
        )
    }

    private let projectStorage: CoreDataProjectStorage
    private let drawingToolStorage: CoreDataDrawingToolStorage
    private let brushPaletteStorage: CoreDataBrushPaletteStorage
    private let eraserPaletteStorage: CoreDataEraserPaletteStorage

    private let projectStorageController: PersistenceController
    private let drawingToolStorageController: PersistenceController

    private let dependencies: HandDrawingViewDependencies

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

    init(
        dependencies: HandDrawingViewDependencies? = nil
    ) {
        self.dependencies = dependencies ?? .init()
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
    }

    func loadLocalDrawingComponentsData(configuration: ProjectConfiguration) {
        // Retain the file suffix
        _fileSuffix = configuration.fileSuffix

        // Fetch data from Core Data
        do {
            try fetchDataFromCoreDataIfAvailable()
        } catch {
            Logger.error(error)
        }

        Task {
            // Create a list of file items
            await fileItemList(
                fileSuffix: _fileSuffix
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
                try dependencies.textureLayersDocumentsRepository.restoreStorageFromWorkingDirectory(
                    textureLayers: restoredTextureLayerDataFromCoreData,
                    device: device
                )
                textureLayersData = restoredTextureLayerDataFromCoreData
                resolvedTextureSize = restoredTextureLayerDataFromCoreData.textureSize

            } catch {
                // Initialize using the configuration values when an error occurs
                let newData = await initializeStorage(
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
            let newData = await initializeStorage(
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

    private func initializeStorage(
        device: MTLDevice,
        textureSize: CGSize,
        commandQueue: MTLCommandQueue
    ) async -> TextureLayersModel {
        let data = TextureLayersModel(textureSize: textureSize)

        do {
            try await dependencies.textureLayersDocumentsRepository.initializeStorage(
                textureLayers: data,
                device: device,
                commandQueue: commandQueue
            )
        } catch {
            fatalError("Failed to initialize storage")
        }

        return data
    }
}

extension HandDrawingViewModel {
    func onSaveFiles(
        thumbnail: UIImage?,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            // Save the thumbnail image into the working directory
            try thumbnail?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent("thumbnail.png")
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the thumbnail")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Copy the texture files into the working directory
            for layer in textureLayersState.layers {
                try await dependencies.textureLayersDocumentsRepository.copyTexture(
                    id: layer.id,
                    to: workingDirectoryURL
                )
            }
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to create the textures")
            )
            Logger.error(error)
            throw error
        }

        do {
            // Save the texture layers as JSON
            try TextureLayersArchiveModel(
                layers: textureLayersState.layers.map { .init(item: $0) },
                layerIndex: textureLayersState.selectedIndex ?? 0,
                textureSize: textureLayersState.textureSize
            ).write(
                in: workingDirectoryURL
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Failed to save the texture layers")
            )
            Logger.error(error)
            throw error
        }
    }

    func onLoadFiles(
        device: MTLDevice,
        from workingDirectoryURL: URL
    ) async throws {
        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let data: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        guard try await dependencies.textureLayersDocumentsRepository.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: data,
            device: device
        ) else {
            return
        }

        textureLayersState.update(data)
    }

    func onNewCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        let data: TextureLayersModel = .init(
            textureSize: textureLayersState.textureSize
        )

        try await dependencies.textureLayersDocumentsRepository.initializeStorage(
            textureLayers: data,
            device: device,
            commandQueue: commandQueue
        )

        textureLayersState.update(data)
    }
}

extension HandDrawingViewModel {
    func projectFileName() -> String {
        if _fileSuffix.isEmpty {
            return project.projectName
        } else {
            return project.projectName + "." + _fileSuffix
        }
    }

    func toggleDrawingTool() {
        drawingTool.swapTool(drawingTool.type)
    }

    func resetCoreData() {
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
            projectName: Calendar.currentDate,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

extension HandDrawingViewModel {

    func onSaveCanvas(
        saveCanvasAction: ((URL) async throws -> Void)?,
        completion: (() -> Void)?,
        zipFileURL: URL
    ) {
        Task(priority: .userInitiated) { [weak self] in
            guard let `self` else { return }

            defer {
                /// Remove the working space
                try? dependencies.localFileRepository.removeWorkingDirectory()

                self.activityIndicatorSubject.send(false)
            }
            self.activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory for saving project files
                try dependencies.localFileRepository.createWorkingDirectory()

                let workingDirectoryURL = dependencies.localFileRepository.workingDirectoryURL

                try await saveCanvasAction?(workingDirectoryURL)

                try DrawingToolArchiveModel(drawingTool).write(in: workingDirectoryURL)
                try BrushPaletteArchiveModel(brushPalette).write(in: workingDirectoryURL)
                try EraserPaletteArchiveModel(eraserPalette).write(in: workingDirectoryURL)
                try ProjectArchiveModel(project).write(in: workingDirectoryURL)

                // Zip the working directory into a single project file
                try dependencies.localFileRepository.zipWorkingDirectory(to: zipFileURL)

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

    func onLoadCanvas(
        zipFileURL: URL,
        action: ((URL) async throws -> Void)?,
        completion: (() -> Void)?
    ) {
        Task { [weak self] in
            guard let `self` else { return }

            defer {
                // Remove the working space
                try? dependencies.localFileRepository.removeWorkingDirectory()

                self.activityIndicatorSubject.send(false)
            }
            self.activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory
                try dependencies.localFileRepository.createWorkingDirectory()

                let workingDirectoryURL = dependencies.localFileRepository.workingDirectoryURL

                // Extract the zip file into the working directory
                try await dependencies.localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                try await action?(workingDirectoryURL)

                // Throw an error if the project name cannot be retrieved
                try self.projectStorage.update(directoryURL: workingDirectoryURL)

                // Since it’s optional, ignore any errors that occur
                try? self.drawingToolStorage.update(directoryURL: workingDirectoryURL)
                try? self.brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                try? self.eraserPaletteStorage.update(directoryURL: workingDirectoryURL)

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
        if let index = _fileList.firstIndex(where: { $0.title == file.title }) {
            _fileList[index] = file
        } else {
            _fileList.append(file)
        }

        _fileList.sort { $0.updatedAt > $1.updatedAt }
    }

    private func fileItemList(fileSuffix: String) async {
        var fileNames: [String] = []

        URL.documents.allFileURLs(suffix: fileSuffix).map {
            $0.lastPathComponent
        }.forEach {
            fileNames.append($0)
        }

        for fileName in fileNames {
            do {
                defer { try? dependencies.localFileRepository.removeWorkingDirectory() }
                try dependencies.localFileRepository.createWorkingDirectory()

                let workingDirectoryURL = dependencies.localFileRepository.workingDirectoryURL

                let zipFileURL = URL.documents.appendingPathComponent(fileName)

                try await dependencies.localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                // Load project metadata
                let projectMetaData: ProjectArchiveModel = try .init(
                    in: workingDirectoryURL
                )

                // Load the thubnail
                let data = try Data(
                    contentsOf: workingDirectoryURL.appendingPathComponent(thumbnailName)
                )

                _fileList.append(
                    .init(
                        title: projectMetaData.projectName,
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        thumbnail: UIImage(data: data),
                        fileURL: zipFileURL
                    )
                )
            } catch {
                Logger.error(error)
            }
        }

        _fileList.sort { $0.updatedAt > $1.updatedAt }
    }
}
