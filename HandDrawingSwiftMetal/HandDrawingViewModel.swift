//
//  HandDrawingViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Combine
import CanvasView
import UIKit

@MainActor
final class HandDrawingViewModel: ObservableObject {

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

    var fileSuffix: String {
        _fileSuffix
    }
    private var _fileSuffix: String = ""

    var fileList: [LocalFileItem] {
        _fileList
    }
    private var _fileList: [LocalFileItem] = []

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette
    let eraserPalette: EraserPalette

    private let projectStorage: CoreDataProjectStorage
    private let drawingToolStorage: CoreDataDrawingToolStorage
    private let brushPaletteStorage: CoreDataBrushPaletteStorage
    private let eraserPaletteStorage: CoreDataEraserPaletteStorage

    private let projectStorageController: PersistenceController
    private let drawingToolStorageController: PersistenceController

    /// Repository that manages files in the Documents directory
    private let localFileRepository: LocalFileRepository = LocalFileRepository(
        workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
    )

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    public var alert: AnyPublisher<any Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<any Error, Never>()

    public var toast: AnyPublisher<ToastMessage, Never> {
        toastSubject.eraseToAnyPublisher()
    }
    private let toastSubject = PassthroughSubject<ToastMessage, Never>()

    public init() {

        self.brushPalette = .init(colors: initializeColors)

        self.eraserPalette = .init(alphas: initializeAlphas)

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

    func setup(configuration: CanvasConfiguration) throws {
        // Retain the file suffix
        _fileSuffix = configuration.fileSuffix

        // Fetch data from Core Data
        try fetchDataFromCoreDataIfAvailable()

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
    func loadFile(
        zipFileURL: URL,
        action: ((URL) async throws -> Void)?,
        completion: (() -> Void)?
    ) {
        Task {
            defer {
                // Remove the working space
                localFileRepository.removeWorkingDirectory()

                activityIndicatorSubject.send(false)
            }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory
                let workingDirectoryURL = try localFileRepository.createWorkingDirectory()

                // Extract the zip file into the working directory
                try await localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                try await action?(workingDirectoryURL)

                // Throw an error if the project name cannot be retrieved
                try projectStorage.update(directoryURL: workingDirectoryURL)

                // Since it’s optional, ignore any errors that occur
                try? drawingToolStorage.update(directoryURL: workingDirectoryURL)
                try? brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                try? eraserPaletteStorage.update(directoryURL: workingDirectoryURL)

                completion?()

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                alertSubject.send(error)
            }
        }
    }

    func saveProject(
        action: ((URL) async throws -> Void)?,
        completion: (() -> Void)?,
        zipFileURL: URL
    ) {
        Task(priority: .userInitiated) {
            defer {
                /// Remove the working space
                localFileRepository.removeWorkingDirectory()

                activityIndicatorSubject.send(false)
            }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory for saving project files
                let workingDirectoryURL = try localFileRepository.createWorkingDirectory()

                try await action?(workingDirectoryURL)

                try DrawingToolArchiveModel(drawingTool).write(in: workingDirectoryURL)
                try BrushPaletteArchiveModel(brushPalette).write(in: workingDirectoryURL)
                try EraserPaletteArchiveModel(eraserPalette).write(in: workingDirectoryURL)
                try ProjectArchiveModel(project).write(in: workingDirectoryURL)

                // Zip the working directory into a single project file
                try localFileRepository.zipWorkingDirectory(to: zipFileURL)

                completion?()

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                alertSubject.send(error)
            }
        }
    }
}

extension HandDrawingViewModel {
    func upsertFileList(fileItem: LocalFileItem) {
        if let index = _fileList.firstIndex(where: { $0.title == fileItem.title }) {
            _fileList[index] = fileItem
        } else {
            _fileList.append(fileItem)
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
                defer { localFileRepository.removeWorkingDirectory() }
                let workingDirectoryURL = try localFileRepository.createWorkingDirectory()
                let zipFileURL = URL.documents.appendingPathComponent(fileName)

                try await localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                // Load project metadata
                let projectMetaData: ProjectArchiveModel = try .init(
                    in: workingDirectoryURL
                )

                // Load the thubnail
                let data = try Data(
                    contentsOf: workingDirectoryURL.appendingPathComponent(CanvasView.thumbnailName)
                )

                _fileList.append(
                    .init(
                        title: projectMetaData.projectName,
                        createdAt: projectMetaData.createdAt,
                        updatedAt: projectMetaData.updatedAt,
                        image: UIImage(data: data),
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
