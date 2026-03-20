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

    public var undoTextureInMemoryRepository: UndoTextureInMemoryRepository?

    public var textureLayersState: TextureLayersState?

    private var textureLayerStorage: CoreDataTextureLayerStorage?

    private let textureLayersStorageController: PersistenceController

    private var textureLayerRenderer: TextureLayerRenderer?

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let viewModel: HandDrawingCanvasViewModel = .init()

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailLength: CGFloat = 500

    override init() {
        self.textureLayersStorageController = PersistenceController(
            xcdatamodeldName: "TextureLayerStorage"
        )

        super.init()

        self.undoTextureInMemoryRepository = .init(
            renderer: renderer
        )
        self.textureLayersState = TextureLayersState(
            device: sharedDevice
        )

        self.textureLayerRenderer = .init(renderer: renderer)

        guard let textureLayersState else { return }
        self.textureLayerStorage = .init(
            textureLayers: textureLayersState,
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
        /*
        // Update the current texture
        // Mainly used for undoing alpha changes
        textureLayersState?.currentLayerUpdateRequested
            .sink { [weak self] in
                self?.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        // Update the canvas with a new texture
        // Mainly used for undoing drawing operations
        textureLayersState?.currentLayerUpdateWithNewCurrentTextureRequested
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
        textureLayersState?.fullCanvasUpdateRequested
            .sink { [weak self] in
                Task {
                    try? await self?.updateFullCanvasTexture()
                }
            }
            .store(in: &cancellables)
        */
    }

    private func completeDrawing() {
        drawingDebouncer.perform {
            Task(priority: .utility) { [weak self] in
                guard
                    let `self`,
                    let currentTexture = self.currentTexture,
                    let layerId = self.textureLayersState?.selectedLayer?.id
                else { return }

                do {
                    try await self.viewModel.writeTexture(
                        texture: currentTexture,
                        for: layerId,
                        device: self.sharedDevice
                    )

                    self.textureLayersState?.updateThumbnail(
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
            let textureLayersState,
            let selectedLayer = textureLayersState.selectedLayer,
            let textureLayers: TextureLayersRenderContext = .init(state: textureLayersState),
            let currentTexture = try await viewModel.duplicatedTexture(
                selectedLayer.id,
                device: sharedDevice
            )?.texture
        else {
            return
        }

        try setCurrentTexture(currentTexture)

        let textures = try await viewModel.duplicatedTextures(
            textureLayers.layers.map { $0.id },
            device: sharedDevice
        ) ?? []

        try await textureLayerRenderer?.refreshTextures(
            textureLayers: textureLayers,
            textures: textures
        )

        updateCanvasTextureUsingCurrentTexture()
    }

    override func completeCanvasCreation(_ textureSize: CGSize) async {
        /*
        if let undoTextureLayers, undoTextureLayers.isUndoEnabled {
            // Initialize the textures used for Undo
            undoTextureLayers.initializeUndoTextures(
                textureSize: textureSize
            )
            resetUndo()
        }
        */

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
            let selectedLayer = textureLayersState?.selectedLayer
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
        guard let textureLayersState else { return }

        let restoredData: TextureLayersModel? = {
            guard
                let entity = try? textureLayerStorage?.fetch(),
                let state = textureLayerStorage?.convertData(from: entity)
            else { return nil }
            return state
        }()

        let data: TextureLayersModel
        let resolvedConfiguration: CanvasConfiguration

        if let restoredData {
            do {
                (data, resolvedConfiguration) = try restoreStorage(
                    configuration: configuration,
                    restoredTextureLayers: restoredData
                )
            } catch {
                // Initialize the storage on error
                (data, resolvedConfiguration) = try await initializedStorage(
                    configuration: configuration
                )
            }

        } else {
            (data, resolvedConfiguration) = try await initializedStorage(
                configuration: configuration
            )
        }

        textureLayersState.update(data)

        try super.setup(resolvedConfiguration)
    }

    func newCanvas() async throws {
        guard let textureLayersState else { return }

        let textureSize = textureLayersState.textureSize

        let data: TextureLayersModel = .init(
            textureSize: textureSize
        )

        try await viewModel.initializeStorage(
            textureLayers: data,
            device: sharedDevice
        )
        textureLayersState.update(data)

        super.resetTransforming()

        try super.createCanvas(textureSize)
    }

    func saveFiles(to workingDirectoryURL: URL) async throws {
        try await viewModel.exportFiles(
            canvasTexture: canvasTexture,
            thumbnailLength: 500,
            textureLayers: textureLayersState,
            device: sharedDevice,
            to: workingDirectoryURL
        )
    }

    func loadFiles(in workingDirectoryURL: URL) async throws {
        guard let textureLayersState else { return }

        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let data: TextureLayersModel = try .init(model: textureLayersArchiveModel)

        try await viewModel.restoreStorage(
            url: workingDirectoryURL,
            textureLayers: data,
            device: sharedDevice
        )
        textureLayersState.update(data)

        try super.createCanvas(data.textureSize)
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
/*
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
                    let textureLayers = self.textureLayers,
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
 */
    }
}

private extension HandDrawingCanvasView {

    func restoreStorage(
        configuration: CanvasConfiguration,
        restoredTextureLayers: TextureLayersModel
    ) throws -> (TextureLayersModel, CanvasConfiguration) {
        try viewModel.restoreStorageFromWorkingDirectory(
            textureLayers: restoredTextureLayers,
            device: sharedDevice
        )

        return (restoredTextureLayers, configuration.newTextureSize(restoredTextureLayers.textureSize))
    }
    func initializedStorage(
        configuration: CanvasConfiguration
    ) async throws -> (TextureLayersModel, CanvasConfiguration) {
        let newData = TextureLayersModel(textureSize: configuration.textureSize)

        try await viewModel.initializeStorage(
            textureLayers: newData,
            device: sharedDevice
        )

        return (newData, configuration)
    }
}
