//
//  Created by Eisuke Kusachi
//

import CanvasView
import Combine
import Core
import FileView
import Metal
import TextureLayerView
import UIKit

@MainActor
final class HandDrawingViewModel: ObservableObject {

    var textureSize: CGSize {
        undoableTextureLayers.textureSize
    }

    let project: ProjectData = .init()
    let drawingTool: DrawingTool = .init()
    let brushPalette: BrushPalette = .init()
    let eraserPalette: EraserPalette = .init()

    let undoableTextureLayers: TextureLayersUndoableState

    let fileList: FileList
    let thumbnailFileName: String

    /// Current file for displaying in the file list
    func currentFileItem(thumbnail: UIImage?) -> FileItem {
        .init(
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            thumbnail: thumbnail,
            fileURL: fileURL(projectName: project.currentProjectName)
        )
    }

    func fileURL(projectName: String) -> URL {
        URL.fileURL(
            in: dependencies.fileManager.documentsDirectory,
            name: projectName,
            fileSuffix: fileList.fileSuffix
        )
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

    /// Updates the canvas and drawing components.
    private(set) var onCanvasUpdate: (@MainActor () async throws -> Void)?

    /// Zip-based project file I/O in Documents (save, open, delete, rename).
    let documentsProjectFileStorage: DocumentsProjectFileStorage

    let dependencies: HandDrawingViewDependencies

    private var cancellables = Set<AnyCancellable>()

    init(
        dependencies: HandDrawingViewDependencies,
        documentsProjectFileStorage: DocumentsProjectFileStorage? = nil,
        fileSuffix: String = "zip",
        thumbnailFileName: String = "thumbnail.png"
    ) {
        self.dependencies = dependencies
        self.thumbnailFileName = thumbnailFileName
        self.fileList = .init(fileSuffix: fileSuffix)
        self.documentsProjectFileStorage = documentsProjectFileStorage ?? .init(fileManager: dependencies.fileManager)
        self.undoableTextureLayers = .init(repository: dependencies.localTextureFileRepository)

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
        canvasView: TextureLayerCanvasView,
        onCanvasUpdate: @escaping @MainActor () async throws -> Void
    ) {
        self.onCanvasUpdate = onCanvasUpdate

        undoableTextureLayers.setup(
            device: device,
            commandQueue: commandQueue,
            canvasView: canvasView
        )
        undoableTextureLayers.setUndo(undoRegister: undoRegister)

        fetchDataFromCoreDataIfAvailable()
    }
}

extension HandDrawingViewModel {
    /// Clears the open canvas in memory and refreshes list metadata (no zip write until save).
    func clearCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        try await makeBlankCanvas(
            device: device,
            commandQueue: commandQueue
        )

        project.update(updatedAt: Date())
        upsertFile(thumbnail: nil)
        fileList.sortItems()

        try await onCanvasUpdate?()
    }

    /// Restores last-session layers, or makes a blank layer when there is no previous session or files are invalid.
    func setupTextureLayers(
        fallbackTextureSize: CGSize,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws -> CGSize {
        if let textureSize = try? setupTextureLayersFromCoreData() {
            return textureSize
        }
        try await makeBlankLayer(
            textureSize: fallbackTextureSize,
            device: device,
            commandQueue: commandQueue
        )
        return fallbackTextureSize
    }

    /// Creates blank canvas textures and resets drawing tool / palettes.
    func makeBlankCanvas(
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) async throws {
        try await makeBlankLayer(
            textureSize: undoableTextureLayers.textureSize,
            device: device,
            commandQueue: commandQueue
        )

        drawingTool.type = .brush
        drawingTool.brushDiameter = 8
        drawingTool.eraserDiameter = 8
        brushPalette.initializeData()
        eraserPalette.initializeData()
    }

    /// Creates one default layer with an empty texture file and applies it as the current layer stack.
    func makeBlankLayer(
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
        // Blank pixel buffer for the layer in the local texture directory.
        try await dependencies.localTextureFileRepository.initializeTexture(
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

    /// Layer pixels from the last session are already in the local texture directory; labels (id, name, order, size) are in Core Data.
    /// Confirms the files exist and match the texture size, then puts that metadata on the layer list.
    /// Returns `nil` when there is no previous session metadata.
    func setupTextureLayersFromCoreData() throws -> CGSize? {
        guard let entity = try dependencies.textureLayerStorage.fetch() else {
            return nil
        }
        let snapshot = TextureLayersSnapshot(entity: entity)
        try dependencies.localTextureFileRepository.validateTextureFilesInLocalDirectory(
            ids: snapshot.layers.map(\.id),
            textureSize: snapshot.textureSize
        )
        undoableTextureLayers.setLayers(snapshot)
        return snapshot.textureSize
    }

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
            Task { await self.dependencies.textureLayerStorage.save(from: self.undoableTextureLayers) }
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
            Task { await self.dependencies.projectStorage.save(from: self.project) }
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
            Task { await self.dependencies.drawingToolStorage.save(from: self.drawingTool) }
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
            Task { await self.dependencies.brushPaletteStorage.save(from: self.brushPalette) }
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
            Task { await self.dependencies.eraserPaletteStorage.save(from: self.eraserPalette) }
        }
        .store(in: &cancellables)
    }
}
