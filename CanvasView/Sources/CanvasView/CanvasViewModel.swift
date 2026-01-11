//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import UIKit

/// A view model that manages canvas rendering and texture layers.
/// `DrawingRenderer` draws onto the textures of `TextureLayers`,
/// `CanvasRenderer` composites those textures and renders the result to the display.
@MainActor
public final class CanvasViewModel {

    /// The frame size, which changes when the screen rotates or the view layout updates.
    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.setFrameSize(frameSize)
            drawingRenderers.forEach { $0.setFrameSize(frameSize) }
        }
    }

    var zipFileURL: URL {
        projectMetaDataStorage.zipFileURL
    }

    /// The size of the texture currently set on the canvas.
    /// A temporary value is assigned to avoid making it optional.
    private(set) var currentTextureSize: CGSize = .init(width: 768, height: 1024)

    /// Emits `true` while drawing is in progress
    var isDrawing: AnyPublisher<Bool, Never> {
        isDrawingSubject.eraseToAnyPublisher()
    }
    private let isDrawingSubject = PassthroughSubject<Bool, Never>()

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasViewModel` setup completes
    var didInitialize: AnyPublisher<CanvasConfigurationResult, Never> {
        didInitializeSubject.eraseToAnyPublisher()
    }
    private let didInitializeSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    /// Metadata stored in Core Data
    private(set) var projectMetaDataStorage: CoreDataProjectMetaDataStorage

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    /// Undoable texture layers
    private let textureLayers: UndoTextureLayers

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    /// A class that manages drawing lines onto textures
    private var drawingRenderer: DrawingRenderer?
    private var drawingRenderers: [DrawingRenderer] = []

    /// Touch phase for drawing
    private var drawingTouchPhase: UITouch.Phase?

    /// A display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let transforming = Transforming()

    /// A debouncer that ensures only the last operation is executed when drawing occurs rapidly
    private let persistanceDrawingDebouncer = Debouncer(delay: 0.25)

    private var dependencies: CanvasViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailName: String = "thumbnail.png"

    public static let thumbnailLength: CGFloat = 500

    init(
        dependencies: CanvasViewDependencies
    ) {
        self.canvasRenderer = dependencies.canvasRenderer
        self.projectMetaDataStorage = dependencies.projectMetaDataStorage
        self.textureLayers = dependencies.textureLayers
        self.dependencies = dependencies
    }

    func setup(
        drawingRenderers: [DrawingRenderer] = [],
        configuration: CanvasConfiguration
    ) async throws {
        self.drawingRenderers = drawingRenderers
        self.drawingRenderer = self.drawingRenderers[0]

        self.bindData()

        let environmentConfiguration = configuration.environmentConfiguration

        self.canvasRenderer.setup(
            backgroundColor: environmentConfiguration.backgroundColor,
            baseBackgroundColor: environmentConfiguration.baseBackgroundColor
        )
        self.setupTouchGesture(
            drawingGestureRecognitionSecond: environmentConfiguration.drawingGestureRecognitionSecond,
            transformingGestureRecognitionSecond: environmentConfiguration.transformingGestureRecognitionSecond
        )
        try await setupCanvas(
            textureLayersState: textureLayersStateFromCoreDataEntity,
            configuration: configuration
        )
    }
}

extension CanvasViewModel {
    func setupCanvas(
        textureLayersState: TextureLayersState?,
        configuration: CanvasConfiguration
    ) async throws {
        // Restore the canvas using textureLayersState if it exists
        if let textureLayersState {
            do {
                // Use metadata from Core Data
                if let entity = try? projectMetaDataStorage.fetch() {
                    projectMetaDataStorage.update(entity)
                }

                try await setupCanvasFromCoreData(
                    textureLayersState: textureLayersState
                )
                return
            } catch {
                Logger.error(error)
            }
        }

        // Setup the canvas with the default settings
        do {
            try await setupDefaultCanvas(
                projectName: configuration.projectConfiguration.projectName,
                textureLayersState: .init(textureSize: configuration.textureSize)
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to initialize the canvas", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
    }

    func restoreCanvasFromDocumentsFolder(
        workingDirectoryURL: URL,
        textureLayersState: TextureLayersState,
        projectMetaData: ProjectMetaData
    ) async throws {
        guard
            let textureLayersDocumentsRepository = dependencies?.textureLayersDocumentsRepository
        else { return }

        // Restore the repository using TextureLayersState
        try await textureLayersDocumentsRepository.restoreStorageFromSavedData(
            url: workingDirectoryURL,
            textureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        // Overwrite the metadata with the given value
        projectMetaDataStorage.update(projectMetaData)

        didInitializeSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }
}

extension CanvasViewModel {
    /// Fetches `textureLayers` data from Core Data.
    /// Returns nil if an error occurs.
    private var textureLayersStateFromCoreDataEntity: TextureLayersState? {
        guard
            let entity = try? (textureLayers.textureLayers as? CoreDataTextureLayers)?.fetch()
        else { return nil }
        return try? .init(entity: entity)
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.update
            .sink { [weak self] in
                self?.onDisplayLinkForDrawing()
            }
            .store(in: &cancellables)

        // Execute when the drawing is complete
        drawingDebouncer.isProcessing
            .sink { [weak self] isProcessing in
                if !isProcessing {
                    // Set isDrawingSubject to false when drawing is complete
                    self?.isDrawingSubject.send(false)
                }
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayers.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)

        // Update the canvas with `RealtimeDrawingTexture`
        textureLayers.canvasDrawingUpdateRequested
            .sink { [weak self] texture in
                guard
                    let `self`,
                    let commandBuffer = self.canvasRenderer.commandBuffer
                else { return }

                self.canvasRenderer.updateSelectedLayerTextures(
                    texture: texture,
                    with: commandBuffer
                )
                self.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayers.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                guard let `self` else { return }
                Task {
                    try await self.canvasRenderer.updateTextures(
                        textureLayers: self.textureLayers
                    )
                    self.commitAndRefreshDisplay()
                }
            }
            .store(in: &cancellables)

        textureLayers.didUndo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didUndoSubject.send(state)
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer.setMatrix(matrix)
            }
            .store(in: &cancellables)

        // Called after the initialization of CanvasViewModel is complete
        didInitializeSubject
            .sink { [weak self] result in
                // Update the thumbnails
                Task {
                    for layer in result.textureLayers.layers {
                        try await self?.textureLayers.updateThumbnail(layer.id)
                    }
                }

                // Update currentTextureSize
                self?.currentTextureSize = result.textureSize

                // Reset undo when the update of CanvasViewModel completes
                self?.textureLayers.resetUndo()

                self?.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)
    }

    private func setupTouchGesture(
        drawingGestureRecognitionSecond: TimeInterval,
        transformingGestureRecognitionSecond: TimeInterval
    ) {
        // Set the gesture recognition durations in seconds
        self.touchGesture.setDrawingGestureRecognitionSecond(
            drawingGestureRecognitionSecond
        )
        self.touchGesture.setTransformingGestureRecognitionSecond(
            transformingGestureRecognitionSecond
        )
    }

    private func setupDefaultCanvas(
        projectName: String,
        textureLayersState: TextureLayersState
    ) async throws {
        guard
            let textureLayersDocumentsRepository = dependencies?.textureLayersDocumentsRepository
        else { return }

        // Initialize the repository using TextureLayersState
        try await textureLayersDocumentsRepository.initializeStorage(
            newTextureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        // Update all data using the new project name
        projectMetaDataStorage.updateAll(newProjectName: projectName)

        didInitializeSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }

    private func setupCanvasFromCoreData(
        textureLayersState: TextureLayersState
    ) async throws {
        guard
            let textureLayersDocumentsRepository = dependencies?.textureLayersDocumentsRepository
        else { return }

        // Restore the repository using TextureLayersState
        try textureLayersDocumentsRepository.restoreStorageFromCoreData(
            textureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        // Update only the updatedAt field, since the metadata may be loaded from Core Data
        projectMetaDataStorage.updateUpdatedAt()

        didInitializeSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }

    /// Sets up `CanvasRenderer` with updated `textureLayers`
    private func setupCanvasRenderer(textureLayersState: TextureLayersState) async throws {
        let textureSize = textureLayersState.textureSize

        // Update textureLayers using textureLayersState
        textureLayers.updateSkippingThumbnail(
            textureLayersState: textureLayersState
        )

        // Update canvasRenderer using textureLayers
        try canvasRenderer.initializeTextures(
            textureSize: textureSize
        )
        try await canvasRenderer.updateTextures(
            textureLayers: textureLayers
        )

        // Initialize the textures in DrawingRenderer
        for i in 0 ..< drawingRenderers.count {
            drawingRenderers[i].initializeTextures(
                textureSize: textureSize
            )
        }

        // Initialize the textures used for Undo
        if textureLayers.isUndoEnabled {
            textureLayers.initializeUndoTextures(
                textureSize: textureSize
            )
        }
    }
}

extension CanvasViewModel {

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        inputDevice.update(.finger)

        // Return if a pen input is in progress
        guard inputDevice.isNotPencil else { return }

        fingerStroke.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch touchGesture.update(fingerStroke.touchHistories) {
        case .drawing:
            guard
                let drawingRenderer,
                let textureSize = canvasRenderer.textureSize,
                let displayTextureSize = canvasRenderer.displayTextureSize
            else { return }

            // Execute if finger drawing has not yet started
            if fingerStroke.isFingerDrawingInactive {

                // Store the drawing-specific key in the dictionary
                fingerStroke.setStoreKeyForDrawing()

                drawingRenderer.beginFingerStroke()

                isDrawingSubject.send(true)

                Task {
                    await textureLayers.setUndoDrawing(
                        texture: canvasRenderer.selectedLayerTexture
                    )
                }
            }

            let pointArray = fingerStroke.drawingPoints(after: fingerStroke.drawingLineEndPoint)

            // Update the touch phase for drawing
            drawingTouchPhase = touchPhase(pointArray)

            drawingRenderer.appendStrokePoints(
                strokePoints:  pointArray.map {
                    .init(
                        location: CGAffineTransform.texturePoint(
                            screenPoint: $0.preciseLocation,
                            matrix: transforming.matrix,
                            textureSize: textureSize,
                            drawableSize: displayTextureSize,
                            frameSize: frameSize
                        ),
                        brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                        diameter: CGFloat(drawingRenderer.diameter)
                    )
                },
                touchPhase: pointArray.currentTouchPhase
            )

            fingerStroke.updateDrawingLineEndPoint()

            drawingDisplayLink.run(isCurrentlyDrawing)

        case .transforming:
            transformCanvas()

        default: break
        }

        // Remove unused finger arrays from the dictionary
        fingerStroke.removeEndedTouchArrayFromDictionary()

        // Reset all parameters when all fingers are lifted off the screen
        if UITouch.isAllFingersReleasedFromScreen(event: event) {
            resetFingerGestureParameters()
        }
    }

    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        // Reset parameters if a finger drawing is in progress
        if inputDevice.isFinger {
            resetTouchRelatedParameters()
        }
        inputDevice.update(.pencil)

        pencilStroke.setLatestEstimatedTouchPoint(
            estimatedTouches
                .filter({ $0.type == .pencil })
                .sorted(by: { $0.timestamp < $1.timestamp })
                .last
                .map { .init(touch: $0, view: view) }
        )
    }

    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        guard
            let drawingRenderer,
            let textureSize = canvasRenderer.textureSize,
            let displayTextureSize = canvasRenderer.displayTextureSize
        else { return }

        /// Execute if it’s the beginning of a touch
        if actualTouches.contains(where: { $0.phase == .began }) {

            drawingRenderer.beginPencilStroke()

            isDrawingSubject.send(true)

            Task {
                await textureLayers.setUndoDrawing(
                    texture: canvasRenderer.selectedLayerTexture
                )
            }
        }

        pencilStroke.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { .init(touch: $0, view: view) }
        )

        let pointArray = pencilStroke.drawingPoints(after: pencilStroke.drawingLineEndPoint)

        // Update the touch phase for drawing
        drawingTouchPhase = touchPhase(pointArray)

        drawingRenderer.appendStrokePoints(
            strokePoints:  pointArray.map {
                .init(
                    location: CGAffineTransform.texturePoint(
                        screenPoint: $0.preciseLocation,
                        matrix: transforming.matrix,
                        textureSize: textureSize,
                        drawableSize: displayTextureSize,
                        frameSize: frameSize
                    ),
                    brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                    diameter: CGFloat(drawingRenderer.diameter)
                )
            },
            touchPhase: pointArray.currentTouchPhase
        )
        pencilStroke.setDrawingLineEndPoint()

        drawingDisplayLink.run(isCurrentlyDrawing)
    }

    private func onDisplayLinkForDrawing() {
        guard
            let drawingRenderer,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture,
            let realtimeDrawingTexture = canvasRenderer.realtimeDrawingTexture,
            let commandBuffer = canvasRenderer.commandBuffer
        else { return }

        drawingRenderer.drawStroke(
            selectedLayerTexture: selectedLayerTexture,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        // The finalization process is performed when drawing is completed.
        if isFinishedDrawing {
            canvasRenderer.renderToSelectedLayer(
                texture: canvasRenderer.realtimeDrawingTexture,
                with: commandBuffer
            )

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    // Reset parameters on drawing completion
                    self?.prepareNextStroke()

                    self?.completeDrawing()
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke()
        }

        commitAndRefreshDisplay(
            displayRealtimeDrawingTexture: drawingRenderer.displayRealtimeDrawingTexture
        )
    }

    /// Called when the display texture size changes, such as when the device orientation changes.
    func onUpdateDisplayTexture() {
        commitAndRefreshDisplay()
    }
}

public extension CanvasViewModel {
    func newCanvas(
        newProjectName: String,
        newTextureSize: CGSize
    ) async throws {
        try await setupDefaultCanvas(
            projectName: newProjectName,
            textureLayersState: TextureLayersState(textureSize: newTextureSize)
        )
        transforming.setMatrix(.identity)
    }

    func resetTransforming() {
        transforming.setMatrix(.identity)
        canvasRenderer.commitAndRefreshDisplay()
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard
            drawingToolIndex < drawingRenderers.count
        else { return }

        drawingRenderer = drawingRenderers[drawingToolIndex]
        drawingRenderer?.prepareNextStroke()
    }

    func undo() {
        textureLayers.undo()
    }
    func redo() {
        textureLayers.redo()
    }

    func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {
        guard let dependencies else { return }

        let device = canvasRenderer.device

        // Save the thumbnail image into the working directory
        try thumbnail(length: thumbnailLength)?.pngData()?.write(
            to: workingDirectoryURL.appendingPathComponent(CanvasViewModel.thumbnailName)
        )

        // Copy all textures from the textureRepository
        let textures = try await dependencies.textureLayersDocumentsRepository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for texture in textures {
                group.addTask {
                    try await texture.write(
                        in: workingDirectoryURL,
                        device: device
                    )
                }
            }
            try await group.waitForAll()
        }

        // Save the texture layers as JSON
        try TextureLayersArchiveModel(
            layers: textureLayers.layers.map { .init(item: $0) },
            layerIndex: textureLayers.selectedIndex ?? 0,
            textureSize: textureLayers.textureSize
        ).write(
            in: workingDirectoryURL
        )

        // Save the project metadata as JSON
       try ProjectMetaDataArchiveModel(
            projectName: projectMetaDataStorage.projectName,
            createdAt: projectMetaDataStorage.createdAt,
            updatedAt: projectMetaDataStorage.updatedAt
        ).write(
            in: workingDirectoryURL
        )
    }

    /// Returns drawing renderers ready for drawing, creating a default renderer if needed.
    static func resolveDrawingRenderers(
        renderer: MTLRendering,
        drawingRenderers: [DrawingRenderer]
    ) -> [DrawingRenderer] {
        var resolvedDrawingRenderers: [DrawingRenderer] = drawingRenderers

        if resolvedDrawingRenderers.isEmpty {
            resolvedDrawingRenderers = [BrushDrawingRenderer()]
        }

        resolvedDrawingRenderers.forEach {
            $0.setup(
                renderer: renderer
            )
        }
        return resolvedDrawingRenderers
    }
}

extension CanvasViewModel {
    private var isCurrentlyDrawing: Bool {
        switch drawingTouchPhase {
        case .began, .moved: return true
        default: return false
        }
    }
    private var isFinishedDrawing: Bool {
        drawingTouchPhase == .ended
    }
    private var isCancelledDrawing: Bool {
        drawingTouchPhase == .cancelled
    }

    private func touchPhase(_ points: [TouchPoint]) -> UITouch.Phase? {
        if points.contains(where: { $0.phase == .cancelled }) {
            return .cancelled
        } else if points.contains(where: { $0.phase == .ended }) {
            return .ended
        } else if points.contains(where: { $0.phase == .began }) {
            return .began
        } else if points.contains(where: { $0.phase == .moved }) {
            return .moved
        }
        return nil
    }

    private func prepareNextStroke() {
        inputDevice.reset()
        touchGesture.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        transforming.resetMatrix()

        drawingDisplayLink.stop()

        drawingTouchPhase = nil

        drawingRenderer?.prepareNextStroke()
    }

    private func resetFingerGestureParameters() {
        touchGesture.reset()

        fingerStroke.reset()
        drawingDisplayLink.stop()
    }
    private func resetTouchRelatedParameters() {
        fingerStroke.reset()

        transforming.resetMatrix()

        drawingRenderer?.prepareNextStroke()

        canvasRenderer.resetCommandBuffer()
        canvasRenderer.commitAndRefreshDisplay()
    }

    private func completeDrawing() {
        guard
            let dependencies,
            let layerId = textureLayers.selectedLayer?.id,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        drawingDebouncer.perform { [weak self] in
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.textureLayersDocumentsRepository.writeTextureToDisk(
                        texture: selectedLayerTexture,
                        for: layerId
                    )

                    self.textureLayers.updateThumbnail(
                        layerId,
                        texture: selectedLayerTexture
                    )

                    // Update `updatedAt` when drawing completes
                    self.projectMetaDataStorage.updateUpdatedAt()

                } catch {
                    Logger.error(error)
                }
            }
        }

        Task {
            try await textureLayers.pushUndoDrawingObjectToUndoStack(
                texture: selectedLayerTexture
            )
        }
    }

    private func transformCanvas() {
        if transforming.isNotKeysInitialized {
            transforming.initialize(
                fingerStroke.touchHistories
            )
        }

        if fingerStroke.hasEndedTouches {
            transforming.endTransformation()
        } else {
            transforming.transformCanvas(
                screenCenter: .init(
                    x: frameSize.width * 0.5,
                    y: frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )
        }

        canvasRenderer.commitAndRefreshDisplay()
    }

    private func commitAndRefreshDisplay(
        displayRealtimeDrawingTexture: Bool = false
    ) {
        guard let selectedLayer = textureLayers.selectedLayer else { return }

        canvasRenderer.commitAndRefreshDisplay(
            displayRealtimeDrawingTexture: displayRealtimeDrawingTexture,
            selectedLayer: selectedLayer
        )
    }

    private func thumbnail(length: CGFloat = CanvasViewModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }
}
