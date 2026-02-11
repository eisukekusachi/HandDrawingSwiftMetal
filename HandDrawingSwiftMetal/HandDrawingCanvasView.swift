//
//  HandDrawingCanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/22.
//

import CanvasView
import Combine
import UIKit
import TextureLayerView

@objc final class HandDrawingCanvasView: CanvasView {

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    public var textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?

    public var undoTextureInMemoryRepository: UndoTextureInMemoryRepository?

    public var undoTextureLayers: UndoTextureLayers?

    private var textureLayerStorage: CoreDataTextureLayerStorage?

    private let textureLayersStorageController: PersistenceController

    private var textureLayersState: TextureLayersState?

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let viewModel = HandDrawingCanvasViewModel()

    override init() {
        self.textureLayersStorageController = PersistenceController(
            xcdatamodeldName: "TextureLayerStorage"
        )
        super.init()
        do {
            self.textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                renderer: renderer
            )
        } catch {
            fatalError("Failed to initialize the canvas")
        }
        self.undoTextureInMemoryRepository = .init(
            renderer: renderer
        )
        self.undoTextureLayers = .init(
            textureLayers: TextureLayers(
                renderer: renderer,
                repository: textureLayersDocumentsRepository
            ),
            renderer: renderer,
            inMemoryRepository: undoTextureInMemoryRepository
        )

        guard let undoTextureLayers else { return }
        self.textureLayerStorage = .init(
            textureLayers: undoTextureLayers,
            context: textureLayersStorageController.viewContext
        )

        bindData()
    }

    @MainActor required init?(coder: NSCoder) {
        self.textureLayersStorageController = PersistenceController(
            xcdatamodeldName: "TextureLayerStorage"
        )
        super.init(coder: coder)
        do {
            self.textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                renderer: renderer
            )
        } catch {
            fatalError("Failed to initialize the canvas")
        }
        self.undoTextureInMemoryRepository = .init(
            renderer: renderer
        )
        self.undoTextureLayers = .init(
            textureLayers: TextureLayers(
                renderer: renderer,
                repository: textureLayersDocumentsRepository
            ),
            renderer: renderer,
            inMemoryRepository: undoTextureInMemoryRepository
        )

        guard let undoTextureLayers else { return }
        self.textureLayerStorage = .init(
            textureLayers: undoTextureLayers,
            context: textureLayersStorageController.viewContext
        )

        bindData()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Configure undoManager here because it may be nil
        // before the view is attached to a window, causing settings to be ignored.
        setupInitialUndoManager()
    }

    func bindData() {

        setupCompletion
            .sink { [weak self] result in
                guard let `self` else { return }
                self.currentTexture = makeTexture(result.textureSize)
            }
            .store(in: &cancellables)

        drawingCompletion
            .sink { [weak self] result in
                self?.drawingDebouncer.perform {
                    Task(priority: .utility) { [weak self] in
                        guard
                            let self,
                            let result,
                            let layerId = self.undoTextureLayers?.selectedLayer?.id
                        else { return }

                        do {
                            try await self.textureLayersDocumentsRepository?.writeTextureToDisk(
                                texture: result,
                                for: layerId
                            )

                            self.undoTextureLayers?.updateThumbnail(
                                layerId,
                                texture: result
                            )

                        } catch {
                            Logger.error(error)
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Update the canvas
        undoTextureLayers?.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.refreshCanvas()
            }
            .store(in: &cancellables)

        // Update the canvas with the texture used for undoing drawing operations
        undoTextureLayers?.canvasDrawingUpdateRequested
            .sink { [weak self] texture in
                self?.updateCurrentTexture(texture)
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        undoTextureLayers?.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                guard let `self` else { return }
                print("fullCanvasUpdateRequestedPublisher")
            }
            .store(in: &cancellables)
    }

    private func setupInitialUndoManager() {
        // Set an initial value to prevent out-of-memory errors when no limit is applied
        undoManager?.levelsOfUndo = 8
    }

    private func makeTexture(_ textureSize: CGSize) -> MTLTexture? {
        MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
    }
}

extension HandDrawingCanvasView {

    func setup(
        drawingRenderers: [DrawingRenderer],
        configuration: CanvasConfiguration
    ) async throws {
        guard
            let undoTextureLayers
        else { return }

        if let entity = try? textureLayerStorage?.fetch(),
           let state = textureLayerStorage?.convertData(entity: entity) {

            textureLayersState = state

            try textureLayersDocumentsRepository?.restoreStorageFromCoreData(
                textureLayersState: state
            )
            undoTextureLayers.updateSkippingThumbnail(
                textureLayersState: state
            )

            try await super.setup(
                textureSize: state.textureSize,
                configuration: configuration
            )
        } else {
            let state: TextureLayersState = .init(textureSize: configuration.textureSize)

            try await textureLayersDocumentsRepository?.initializeStorage(
                newTextureLayersState: state
            )

            undoTextureLayers.updateSkippingThumbnail(
                textureLayersState: state
            )

            try await super.setup(
                textureSize: state.textureSize,
                configuration: configuration
            )
        }
    }

    func setupCompletion(textureSize: CGSize) {
        // Initialize the textures used for Undo
        if let undoTextureLayers, undoTextureLayers.isUndoEnabled {
            undoTextureLayers.initializeUndoTextures(
                textureSize: textureSize
            )
        }
    }

    func newCanvas() async throws {
        guard let undoTextureLayers else { return }

        let textureLayersState: TextureLayersState = .init(
            textureSize: undoTextureLayers.textureSize
        )

        try await textureLayersDocumentsRepository?.initializeStorage(
            newTextureLayersState: textureLayersState
        )
        undoTextureLayers.updateSkippingThumbnail(
            textureLayersState: textureLayersState
        )

        super.resetTransforming()
        try await super.updateCanvas(undoTextureLayers.textureSize)
    }

    func saveFiles(to workingDirectoryURL: URL) async throws {
        try await viewModel.exportFiles(
            canvasTexture: canvasTexture,
            thumbnailLength: 500,
            textureLayers: undoTextureLayers,
            textureLayersDocumentsRepository: textureLayersDocumentsRepository,
            device: sharedDevice,
            to: workingDirectoryURL
        )
    }

    func loadFiles(in workingDirectoryURL: URL) async throws {
        guard let undoTextureLayers else { return }

        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let textureLayerState: TextureLayersState = try .init(model: textureLayersArchiveModel)

        try await textureLayersDocumentsRepository?.restoreStorageFromSavedData(
            url: workingDirectoryURL,
            textureLayersState: textureLayerState
        )
        undoTextureLayers.updateSkippingThumbnail(
            textureLayersState: textureLayerState
        )

        try await super.updateCanvas(textureLayerState.textureSize)
    }
}

extension HandDrawingCanvasView {

    func undo() {
        guard let undoManager else { return }
        undoManager.undo()
        didUndoSubject.send(
            .init(undoManager)
        )
    }
    func redo() {
        guard let undoManager else { return }
        undoManager.redo()
        didUndoSubject.send(
            .init(undoManager)
        )
    }
    func resetUndo() {
        guard let undoManager else { return }
        undoTextureInMemoryRepository?.removeAll()
        undoManager.removeAllActions()
        didUndoSubject.send(
            .init(undoManager)
        )
    }

    func registerUndoObjectPair(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        guard let undoManager else { return }

        undoRedoObject.undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? self.undoTextureInMemoryRepository?.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        undoRedoObject.redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? self.undoTextureInMemoryRepository?.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        undoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject, undoTextureInMemoryRepository] _ in
            Task { [weak self] in
                guard
                    let `self`,
                    let undoTextureLayers = self.undoTextureLayers,
                    let undoTextureInMemoryRepository
                else { return }

                do {
                    try await undoRedoObject.undoObject.applyUndo(
                        layers: undoTextureLayers.textureLayers,
                        repository: undoTextureInMemoryRepository
                    )
                } catch {
                    Logger.error(error)
                }
            }

            // Redo Registration
            self?.registerUndoObjectPair(undoRedoObject.reversed())
        }

        didUndoSubject.send(
            .init(undoManager)
        )
    }
}
