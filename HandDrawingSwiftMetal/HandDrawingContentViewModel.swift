//
//  HandDrawingContentViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/10.
//

import Combine
import CanvasView
import UIKit

@MainActor
final class HandDrawingContentViewModel: ObservableObject {

    private let drawingToolController: PersistenceController

    @Published var drawingToolStorage: CoreDataDrawingToolStorage
    @Published var brushPaletteStorage: CoreDataBrushPaletteStorage
    @Published var eraserPaletteStorage: CoreDataEraserPaletteStorage

    private lazy var drawingToolLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileLoader<DrawingToolArchiveModel>(
                fileName: DrawingToolArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.drawingToolStorage.setDrawingTool(.init(rawValue: file.type))
                    self?.drawingToolStorage.setBrushDiameter(file.brushDiameter)
                    self?.drawingToolStorage.setEraserDiameter(file.eraserDiameter)
                }
            }
         )
    }()

    private lazy var brushPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileLoader<BrushPaletteArchiveModel>(
                fileName: BrushPaletteArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.brushPaletteStorage.update(
                        colors: file.hexColors.compactMap { UIColor(hex: $0) },
                        index: file.index
                    )
                }
            }
         )
    }()

    private lazy var eraserPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileLoader<EraserPaletteArchiveModel>(
                fileName: EraserPaletteArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.eraserPaletteStorage.update(
                        alphas: file.alphas,
                        index: file.index
                    )
                }
            }
         )
    }()

    /// Repository that manages files in the Documents directory
    private let localFileRepository: LocalFileRepository = LocalFileRepository(
        workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
    )

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    private let toastSubject = PassthroughSubject<CanvasMessage, Never>()

    public init() {

        drawingToolController = PersistenceController(xcdatamodeldName: "DrawingToolStorage", location: .mainApp)

        drawingToolStorage = CoreDataDrawingToolStorage(
            drawingTool: DrawingTool(),
            context: drawingToolController.viewContext
        )

        brushPaletteStorage = CoreDataBrushPaletteStorage(
            palette: BrushPalette(
                colors: [
                    .black.withAlphaComponent(0.8),
                    .gray.withAlphaComponent(0.8),
                    .red.withAlphaComponent(0.8),
                    .blue.withAlphaComponent(0.8),
                    .green.withAlphaComponent(0.8),
                    .yellow.withAlphaComponent(0.8),
                    .purple.withAlphaComponent(0.8)
                ]
            ),
            context: drawingToolController.viewContext
        )

        eraserPaletteStorage = CoreDataEraserPaletteStorage(
            palette: EraserPalette(
                alphas: [
                    255,
                    225,
                    200,
                    175,
                    150,
                    125,
                    100,
                    50
                ],
                index: 0
            ),
            context: drawingToolController.viewContext
        )

        Task {
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

    func toggleDrawingTool() {
        drawingToolStorage.setDrawingTool(
            drawingToolStorage.type == .brush ? .eraser: .brush
        )
    }

    func loadFile(
        zipFileURL: URL,
        action: ((URL) async throws -> Void)?
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
                try await FileInput.unzip(
                    sourceURL: zipFileURL,
                    to: workingDirectoryURL,
                    priority: .userInitiated
                )

                try await action?(workingDirectoryURL)

                // Restore data from externally configured entities
                // Since it’s optional, ignore any errors that occur
                let optionalEntities = [
                    self.drawingToolLoader,
                    self.brushPaletteLoader,
                    self.eraserPaletteLoader
                ]
                for entity in optionalEntities {
                    entity.loadIgnoringError(in: workingDirectoryURL)
                }
            }
        }
    }

    func saveProject(
        action: ((URL) async throws -> Void)?,
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

                // Zip the working directory into a single project file
                try localFileRepository.zipWorkingDirectory(
                    to: zipFileURL
                )
            }
        }
    }
}
