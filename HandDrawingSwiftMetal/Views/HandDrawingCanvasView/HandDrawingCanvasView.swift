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

    private var textureLayerRenderer: TextureLayerRenderer?


    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let viewModel = HandDrawingCanvasViewModel()

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailLength: CGFloat = 500

    override init() {
        self.textureLayersStorageController = PersistenceController(
            xcdatamodeldName: "TextureLayerStorage"
        )
        super.init()
        do {
            self.textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                device: sharedDevice
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
        self.textureLayerRenderer = .init(renderer: renderer)

        guard let undoTextureLayers else { return }
        self.textureLayerStorage = .init(
            textureLayers: undoTextureLayers,
            context: textureLayersStorageController.viewContext
        )
        bindData()
    }
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Configure undoManager here because it may be nil
        // before the view is attached to a window, causing settings to be ignored.
        setupInitialUndoManager()
    }

    private func bindData() {

        strokeEvents
            .filter { $0 == .strokeCompleted }
            .sink { [weak self] _ in
                self?.completeDrawing()
            }
            .store(in: &cancellables)

        // Update the current texture
        // Mainly used for undoing alpha changes
        undoTextureLayers?.currentLayerUpdateRequested
            .sink { [weak self] in
                self?.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        // Update the canvas with a new texture
        // Mainly used for undoing drawing operations
        undoTextureLayers?.currentLayerUpdateWithNewCurrentTextureRequested
            .sink { [weak self] texture in
                do {
                    try self?.setCurrentTexture(texture)
                    self?.updateCanvasTextureUsingCurrentTexture()
                } catch {
                    Logger.error(error)
                }
            }
            .store(in: &cancellables)

        // Update the entire canvas
        // Mainly used to undo adding/removing operations
        undoTextureLayers?.fullCanvasUpdateRequested
            .sink { [weak self] in
                Task {
                    try? await self?.updateFullCanvasTexture()
                }
            }
            .store(in: &cancellables)
    }

    private func completeDrawing() {
        drawingDebouncer.perform {
            Task(priority: .utility) { [weak self] in
                guard
                    let currentTexture = self?.currentTexture,
                    let layerId = self?.undoTextureLayers?.selectedLayer?.id
                else { return }

                do {
                    try await self?.textureLayersDocumentsRepository?.writeTextureToDisk(
                        texture: currentTexture,
                        for: layerId
                    )

                    self?.undoTextureLayers?.updateThumbnail(
                        layerId,
                        texture: currentTexture
                    )

                } catch {
                    Logger.error(error)
                }
            }
        }
    }

    func updateFullCanvasTexture() async throws {
        guard
            let undoTextureLayers,
            let selectedLayer = undoTextureLayers.selectedLayer,
            let textureLayers: TextureLayersRenderContext = .init(textureLayers: undoTextureLayers)
        else {
            return
        }

        let currentTexture = try await textureLayerRenderer?.getTexture(
            id: selectedLayer.id,
            repository: textureLayersDocumentsRepository
        )?.texture
        try setCurrentTexture(currentTexture)

        try await textureLayerRenderer?.refreshTexturesFromRepository(
            textureLayers: textureLayers,
            repository: textureLayersDocumentsRepository
        )

        updateCanvasTextureUsingCurrentTexture()
    }

    override func completeCanvasCreation(_ textureSize: CGSize) async {
        if let undoTextureLayers, undoTextureLayers.isUndoEnabled {
            // Initialize the textures used for Undo
            undoTextureLayers.initializeUndoTextures(
                textureSize: textureSize
            )
            resetUndo()
        }

        do {
            try textureLayerRenderer?.initializeTextures(textureSize: textureSize)
            try await updateFullCanvasTexture()
        } catch {
            Logger.error(error)
        }
    }

    override func updateCanvasTextureUsingRealtimeDrawingTexture() {
        updateCanvasTexture(realtimeDrawingTexture)
        present()
    }

    override func updateCanvasTextureUsingCurrentTexture() {
        updateCanvasTexture(currentTexture)
        present()
    }

    private func updateCanvasTexture(_ texture: MTLTexture?) {
        guard
            let selectedLayer = undoTextureLayers?.selectedLayer
        else {
            return
        }

        textureLayerRenderer?.updateCanvasTexture(
            textureLayer: .init(
                isVisible: selectedLayer.isVisible,
                alpha: selectedLayer.alpha,
                texture: texture ?? currentTexture
            ),
            canvasTexture: canvasTexture,
            commandBuffer: currentFrameCommandBuffer
        )
    }

    private func setupInitialUndoManager() {
        // Set an initial value to prevent out-of-memory errors when no limit is applied
        undoManager?.levelsOfUndo = 8
    }
}

extension HandDrawingCanvasView {
    @MainActor
    func setup(
        drawingRenderers: [DrawingRenderer],
        configuration: CanvasConfiguration
    ) async throws {
        guard let undoTextureLayers else { return }

        let restoredState: TextureLayersState? = {
            guard
                let entity = try? textureLayerStorage?.fetch(),
                let state = textureLayerStorage?.convertData(from: entity)
            else { return nil }
            return state
        }()

        let textureLayersState: TextureLayersState
        let resolvedConfiguration: CanvasConfiguration

        if let restoredState {
            textureLayersState = restoredState
            resolvedConfiguration = configuration.newTextureSize(restoredState.textureSize)

            try textureLayersDocumentsRepository?.restoreStorageFromCoreData(
                textureLayersState: textureLayersState
            )
        } else {
            let newState = TextureLayersState(textureSize: configuration.textureSize)
            textureLayersState = newState
            resolvedConfiguration = configuration

            try await textureLayersDocumentsRepository?.initializeStorage(
                newTextureLayersState: textureLayersState
            )
        }

        undoTextureLayers.update(textureLayersState)

        try super.setup(resolvedConfiguration)
    }

    func newCanvas() async throws {
        guard let undoTextureLayers else { return }

        let textureSize = undoTextureLayers.textureSize

        let textureLayersState: TextureLayersState = .init(
            textureSize: textureSize
        )

        try await textureLayersDocumentsRepository?.initializeStorage(
            newTextureLayersState: textureLayersState
        )
        undoTextureLayers.update(textureLayersState)

        super.resetTransforming()

        try super.createCanvas(textureSize)
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
        undoTextureLayers.update(textureLayerState)

        try super.createCanvas(textureLayerState.textureSize)
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
