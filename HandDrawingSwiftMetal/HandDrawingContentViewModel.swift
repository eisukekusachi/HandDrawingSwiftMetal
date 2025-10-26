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

    private let drawingToolController: PersistenceController

    @Published var drawingToolStorage: CoreDataDrawingToolStorage
    @Published var brushPaletteStorage: CoreDataBrushPaletteStorage
    @Published var eraserPaletteStorage: CoreDataEraserPaletteStorage

    /// Repository that manages files in the Documents directory
    private let localFileRepository: LocalFileRepository = LocalFileRepository(
        workingDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("TmpFolder")
    )

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<any Error, Never>()

    public var toast: AnyPublisher<ToastMessage, Never> {
        toastSubject.eraseToAnyPublisher()
    }
    private let toastSubject = PassthroughSubject<ToastMessage, Never>()

    public init() {

        drawingToolController = PersistenceController(xcdatamodeldName: "DrawingToolStorage", location: .mainApp)

        drawingToolStorage = CoreDataDrawingToolStorage(
            drawingTool: DrawingTool(),
            context: drawingToolController.viewContext
        )

        brushPaletteStorage = CoreDataBrushPaletteStorage(
            palette: BrushPalette(
                colors: initializeColors,
                index: 0
            ),
            context: drawingToolController.viewContext
        )

        eraserPaletteStorage = CoreDataEraserPaletteStorage(
            palette: EraserPalette(
                alphas: initializeAlphas,
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
}

extension HandDrawingContentViewModel {
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
                try await localFileRepository.unzipToWorkingDirectory(
                    from: zipFileURL
                )

                try await action?(workingDirectoryURL)

                // Restore data from externally configured entities
                // Since it’s optional, ignore any errors that occur
                try? drawingToolStorage.update(directoryURL: workingDirectoryURL)
                try? brushPaletteStorage.update(directoryURL: workingDirectoryURL)
                try? eraserPaletteStorage.update(directoryURL: workingDirectoryURL)

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

                try DrawingToolArchiveModel(drawingToolStorage.drawingTool).write(in: workingDirectoryURL)
                try BrushPaletteArchiveModel(brushPaletteStorage.palette).write(in: workingDirectoryURL)
                try EraserPaletteArchiveModel(eraserPaletteStorage.palette).write(in: workingDirectoryURL)

                // Zip the working directory into a single project file
                try localFileRepository.zipWorkingDirectory(
                    to: zipFileURL
                )

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
