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

    var didUndo: AnyPublisher<UndoManager, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private var didUndoSubject = PassthroughSubject<UndoManager, Never>()

    var didPerformUndo: AnyPublisher<UndoObject, Never> {
        didPerformUndoSubject.eraseToAnyPublisher()
    }
    private var didPerformUndoSubject = PassthroughSubject<UndoObject, Never>()

    var textureLayersState: TextureLayersState {
        viewModel.textureLayersState
    }

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private lazy var textureLayerRenderer: TextureLayerRenderer = {
        .init(renderer: renderer)
    }()

    private lazy var viewModel: HandDrawingCanvasViewModel = {
        .init(renderer: renderer)
    }()

    private var cancellables = Set<AnyCancellable>()

    var thumbnail: UIImage? {
        canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: 500,
            scale: 1.0
        )
    }

    override init(
        device: MTLDevice? = nil
    ) {
        super.init(device: device)
        self.bindData()
    }

    required init?(coder: NSCoder) {
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
                self?.registerDrawingUndoObjectAfterCompletion(event)
            }
            .store(in: &cancellables)

        viewModel.performUndoSubject
            .sink { [weak self] undoObject in
                self?.performUndo(undoObject)
            }
            .store(in: &cancellables)

        viewModel.updateCanvasTextureSubject
            .sink { [weak self] texture in
                guard let `self` else { return }
                if let texture {
                    try? self.setCurrentTexture(texture)
                }
                self.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        viewModel.updateFullCanvasTextureSubject
            .sink {
                Task { [weak self] in
                    guard let `self` else { return }
                    try? await self.updateFullCanvasTexture()
                }
            }
            .store(in: &cancellables)
    }

    private func completeDrawing() {
        drawingDebouncer.perform {
            Task(priority: .utility) { [weak self] in
                guard let `self` else { return }

                do {
                    try await self.viewModel.onCompleteDrawing(
                        texture: self.currentTexture
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
            let currentTexture = try await viewModel.duplicateTextureFromDocumentsDirectory(
                selectedLayer.id
            )
        else {
            return
        }

        let textures = try await viewModel.duplicateTexturesFromDocumentsDirectory(
            textureLayers.layers.map { $0.id }
        )

        try await textureLayerRenderer.refreshUnselectedTextures(
            textureLayers: textureLayers,
            textures: textures
        )
        try setCurrentTexture(currentTexture)

        updateCanvasTextureUsingCurrentTexture()
    }

    override func completeCanvasCreation(_ textureSize: CGSize) async {
        // Initialize the textures used for Undo
        viewModel.undoDrawing?.initializeUndoTextures(
            textureSize: textureSize
        )
        resetUndo()

        do {
            try textureLayerRenderer.initializeTextures(textureSize: textureSize)
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

        textureLayerRenderer.updateCanvasTexture(
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
            commandQueue: renderer.commandQueue
        )
        try super.setup(resolvedConfiguration)
    }

    func newCanvas() async throws {
        try await viewModel.onNewCanvas()
        try super.createCanvas(viewModel.textureSize)
        super.resetTransforming()
    }

    func saveFiles(to workingDirectoryURL: URL) async throws {
        try await viewModel.onSaveFiles(
            thumbnail: thumbnail,
            to: workingDirectoryURL
        )
    }

    func loadFiles(in workingDirectoryURL: URL) async throws {
        try await viewModel.onLoadFiles(from: workingDirectoryURL)
        try super.createCanvas(viewModel.textureSize)
    }

    func undo() {
        guard let undoManager else { return }
        undoManager.undo()
        didUndoSubject.send(undoManager)
    }
    func redo() {
        guard let undoManager else { return }
        undoManager.redo()
        didUndoSubject.send(undoManager)
    }
    func resetUndo() {
        guard let undoManager else { return }
        viewModel.clearUndoTextures()
        undoManager.removeAllActions()
        didUndoSubject.send(undoManager)
    }

    func registerUndoObject(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        guard let undoManager else { return }
        viewModel.registerUndoObjectPair(
            undoManager,
            undoRedoObject
        )
        didUndoSubject.send(undoManager)
    }
}

extension HandDrawingCanvasView {
    private func registerDrawingUndoObjectAfterCompletion(_ event: StrokeEvent) {
        switch event {
        case .fingerStrokeBegan, .pencilStrokeBegan:
            Task {
                await viewModel.undoDrawing?.setUndoDrawing(
                    texture: currentTexture
                )
            }
        case .strokeCompleted:
            Task {
                guard
                    let selectedLayer = viewModel.textureLayersState.selectedLayer,
                    let undoRedoObjectPair = try await viewModel.undoDrawing?.pushUndoDrawingObject(
                        selectedLayer: selectedLayer,
                        texture: currentTexture
                    )
                 else {
                    return
                }
                registerUndoObject(undoRedoObjectPair)
            }
        case .strokeCancelled:
            break
        }
    }

    private func performUndo(_ undoObject: UndoObject) {
        Task { [weak self] in
            if let undoObject = undoObject as? UndoDrawingObject {
                await self?.viewModel.performDrawingUndo(undoObject)
            } else if let undoObject = undoObject as? UndoAdditionObject {
                await self?.viewModel.performAdditionUndo(undoObject)
            } else if let undoObject = undoObject as? UndoDeletionObject {
                await self?.viewModel.performDeletionUndo(undoObject)
            } else if let undoObject = undoObject as? UndoSelectionObject {
                await self?.viewModel.performSelectUndo(undoObject)
            } else if let undoObject = undoObject as? UndoMoveObject {
                self?.viewModel.performMoveUndo(undoObject)
            } else if let undoObject = undoObject as? UndoAlphaObject {
                await self?.viewModel.performAlphaUndo(undoObject)
            } else if let undoObject = undoObject as? UndoVisibilityObject {
                await self?.viewModel.performVisibilityUndo(undoObject)
            } else if let undoObject = undoObject as? UndoTitleObject {
                await self?.viewModel.performTitleUndo(undoObject)
            }
            self?.didPerformUndoSubject.send(undoObject)
        }
    }
}
