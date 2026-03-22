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

    var textureLayersState: TextureLayersState {
        viewModel.textureLayersState
    }

    private var undoTextureLayers: UndoTextureLayers?

    public var undoTextureInMemoryRepository: UndoTextureInMemoryRepository = .init()

    private var textureLayerRenderer: TextureLayerRenderer?

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private var viewModel: HandDrawingCanvasViewModel = .init(
        dependencies: .init()
    )

    private var cancellables = Set<AnyCancellable>()

    public var thumbnail: UIImage? {
        canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: 500,
            scale: 1.0
        )
    }

    override init(device: MTLDevice? = nil) {
        super.init(device: device)
        self.textureLayerRenderer = .init(renderer: renderer)
        self.undoTextureLayers = .init(
            textureLayers: viewModel.textureLayersState,
            renderer: renderer,
            inMemoryRepository: undoTextureInMemoryRepository
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
            .sink { [weak self] event in
                if case .strokeCompleted = event {
                    self?.completeDrawing()
                }
                self?.handleUndoUpdates(event)
            }
            .store(in: &cancellables)

        undoTextureLayers?.didEmitUndoObjectPair
            .sink { [weak self] undoObjectPair in
                self?.registerUndoObjectPair(undoObjectPair)
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
                guard let `self` else { return }

                do {
                    try await self.viewModel.onCompleteDrawing(
                        texture: self.currentTexture,
                        device: self.sharedDevice
                    )
                } catch {
                    Logger.error(error)
                }
            }
        }
    }

    func updateFullCanvasTexture() async throws {
        guard
            let selectedLayer = textureLayersState.selectedLayer,
            let textureLayers: TextureLayersRenderContext = .init(state: textureLayersState),
            let currentTexture = try await viewModel.duplicatedTexture(
                selectedLayer.id,
                device: sharedDevice
            )
        else {
            return
        }

        let textures = try await viewModel.duplicatedTextures(
            textureLayers.layers.map { $0.id },
            device: sharedDevice
        )

        try await textureLayerRenderer?.refreshUnselectedTextures(
            textureLayers: textureLayers,
            textures: textures
        )
        try setCurrentTexture(currentTexture)

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
        guard let selectedLayer = textureLayersState.selectedLayer else { return }

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
    func setup(
        drawingRenderers: [DrawingRenderer],
        configuration: CanvasConfiguration
    ) async throws {
        let resolvedConfiguration = try await viewModel.onSetup(
            configuration: configuration,
            device: sharedDevice
        )
        try super.setup(resolvedConfiguration)
    }

    func newCanvas() async throws {
        try await viewModel.onNewCanvas(device: sharedDevice)
        try super.createCanvas(viewModel.textureSize)
        super.resetTransforming()
    }

    func saveFiles(to workingDirectoryURL: URL) async throws {
        try await viewModel.onSaveFiles(
            thumbnail: thumbnail,
            device: sharedDevice,
            to: workingDirectoryURL
        )
    }

    func loadFiles(in workingDirectoryURL: URL) async throws {
        try await viewModel.onLoadFiles(device: sharedDevice, from: workingDirectoryURL)
        try super.createCanvas(viewModel.textureSize)
    }
}

extension HandDrawingCanvasView {

    private func handleUndoUpdates(_ event: StrokeEvent) {
        switch event {
        case .fingerStrokeBegan, .pencilStrokeBegan:
            Task {
                await undoTextureLayers?.setUndoDrawing(
                    texture: currentTexture
                )
            }
        case .strokeCompleted:
            Task {
                try await undoTextureLayers?.pushUndoDrawingObjectToUndoStack(
                    texture: currentTexture
                )
            }
        case .strokeCancelled:
            break
        }
    }

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
        undoTextureInMemoryRepository.removeAll()
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
                try? self.undoTextureInMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        undoRedoObject.redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? self.undoTextureInMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        undoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject, undoTextureInMemoryRepository] _ in
            Task { [weak self] in
                guard let `self` else { return }

                guard
                    let undoObject = undoRedoObject.undoObject as? UndoDrawingObject,
                    let undoTextureId = undoObject.undoTextureId,
                    let newTexture = try await MTLTextureCreator.duplicateTexture(
                        texture: undoTextureInMemoryRepository.texture(id: undoTextureId),
                        renderer: renderer
                    )
                else { return }

                let textureLayerId = undoObject.textureLayer.id

                try? self.setCurrentTexture(newTexture)
                self.viewModel.textureLayersState.selectLayer(textureLayerId)
                self.updateCanvasTextureUsingCurrentTexture()

                Task {
                    try? await self.viewModel.saveTexture(
                        layerId: textureLayerId,
                        texture: newTexture,
                        device: self.sharedDevice
                    )
                    self.viewModel.textureLayersState.updateThumbnail(textureLayerId, texture: newTexture)
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
