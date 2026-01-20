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

    /// The size of the texture currently set on the canvas.
    /// A temporary value is assigned to avoid making it optional.
    private(set) var currentTextureSize: CGSize = .init(width: 768, height: 1024)

    /// Emits `true` while drawing is in progress
    var isDrawing: AnyPublisher<Bool, Never> {
        isDrawingSubject.eraseToAnyPublisher()
    }
    private let isDrawingSubject = PassthroughSubject<Bool, Never>()

    private var isFinishedDrawing: Bool {
        drawingTouchPhase == .ended
    }
    private var isCancelledDrawing: Bool {
        drawingTouchPhase == .cancelled
    }

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

    /// Display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer = .init(delay: 0.25)

    private let transforming = Transforming()

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailLength: CGFloat = 500

    init(
        dependencies: CanvasViewDependencies
    ) {
        self.canvasRenderer = dependencies.canvasRenderer
        self.projectMetaDataStorage = dependencies.projectMetaDataStorage
        self.textureLayers = dependencies.textureLayers
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
        // Restore the repository using TextureLayersState
        try await canvasRenderer.textureLayersDocumentsRepository.restoreStorageFromSavedData(
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
    /// Fetches `textureLayers` data from Core Data, returns nil if an error occurs.
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
                self?.onDrawingDisplayLinkFrame()
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
                self?.refreshCanvasAfterComposition()
            }
            .store(in: &cancellables)

        // Update the canvas with the texture used for undoing drawing operations
        textureLayers.canvasDrawingUpdateRequested
            .sink { [weak self] texture in
                guard
                    let `self`,
                    let currentFrameCommandBuffer = self.canvasRenderer.currentFrameCommandBuffer
                else { return }

                self.canvasRenderer.drawSelectedLayerTexture(
                    from: texture,
                    with: currentFrameCommandBuffer
                )
                self.refreshCanvasAfterComposition()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayers.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                guard
                    let `self`,
                    let context = CanvasTextureLayersContext(textureLayers: self.textureLayers)
                else { return }
                Task {
                    try await self.canvasRenderer.refreshTexturesFromRepository(
                        context: context
                    )
                    self.refreshCanvasAfterComposition()
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

                self?.refreshCanvasAfterComposition()
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
        // Initialize the repository using TextureLayersState
        try await canvasRenderer.textureLayersDocumentsRepository.initializeStorage(
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
        // Restore the repository using TextureLayersState
        try canvasRenderer.textureLayersDocumentsRepository.restoreStorageFromCoreData(
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

        guard
            let context = CanvasTextureLayersContext(textureLayers: textureLayers)
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to initialize the canvas", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        // Update canvasRenderer using textureLayers
        try canvasRenderer.setupTextures(
            textureSize: textureSize
        )
        try await canvasRenderer.refreshTexturesFromRepository(
            context: context
        )

        // Initialize the textures in DrawingRenderer
        for i in 0 ..< drawingRenderers.count {
            drawingRenderers[i].setupTextures(
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

    /// Processes finger touches and determines whether the gesture is drawing or transforming
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
            drawingTouchPhase = drawingTouchPhase(pointArray)

            drawingRenderer.appendStrokePoints(
                strokePoints: makeStrokePoints(
                    from: pointArray,
                    textureSize: textureSize,
                    displayTextureSize: displayTextureSize,
                    frameSize: frameSize,
                    diameter: CGFloat(drawingRenderer.diameter)
                ),
                touchPhase: pointArray.currentTouchPhase
            )

            fingerStroke.updateDrawingLineEndPoint()

            drawingDisplayLink.run(
                drawingTouchPhase ?? .ended
            )

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

    /// Processes pencil input using estimated touches
    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        // Reset parameters if a finger drawing is in progress
        if inputDevice.isFinger {
            resetFingerDrawingRelatedParameters()
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

    /// Processes pencil input using actual touches
    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        guard
            let drawingRenderer,
            let textureSize = canvasRenderer.textureSize,
            let displayTextureSize = canvasRenderer.displayTextureSize
        else { return }

        // Execute if it’s the beginning of a touch
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
        drawingTouchPhase = drawingTouchPhase(pointArray)

        drawingRenderer.appendStrokePoints(
            strokePoints: makeStrokePoints(
                from: pointArray,
                textureSize: textureSize,
                displayTextureSize: displayTextureSize,
                frameSize: frameSize,
                diameter: CGFloat(drawingRenderer.diameter)
            ),
            touchPhase: pointArray.currentTouchPhase
        )
        pencilStroke.setDrawingLineEndPoint()

        drawingDisplayLink.run(
            drawingTouchPhase ?? .ended
        )
    }

    /// Called on every display-link frame while drawing is active
    private func onDrawingDisplayLinkFrame() {
        guard
            let drawingRenderer,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture,
            let realtimeDrawingTexture = canvasRenderer.realtimeDrawingTexture,
            let currentFrameCommandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        drawingRenderer.drawStroke(
            baseTexture: selectedLayerTexture,
            on: realtimeDrawingTexture,
            with: currentFrameCommandBuffer
        )

        // The finalization process is performed when drawing is completed
        if isFinishedDrawing {
            canvasRenderer.drawSelectedLayerTexture(
                from: canvasRenderer.realtimeDrawingTexture,
                with: currentFrameCommandBuffer
            )

            currentFrameCommandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    // Reset parameters on drawing completion
                    self?.prepareNextStroke()

                    self?.onCompleteDrawing()
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke()
        }

        refreshCanvasAfterComposition(
            useRealtimeDrawingTexture: drawingRenderer.displayRealtimeDrawingTexture
        )
    }

    /// Called when a stroke is completed
    private func onCompleteDrawing() {
        guard
            let layerId = textureLayers.selectedLayer?.id,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        drawingDebouncer.perform { [weak self] in
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    try await self.canvasRenderer.textureLayersDocumentsRepository.writeTextureToDisk(
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

    /// Called when the display texture size changes, such as when the device orientation changes
    func onUpdateDisplayTexture() {
        refreshCanvasAfterComposition()
    }
}

public extension CanvasViewModel {

    /// Touch phase used for drawing
    func drawingTouchPhase(_ points: [TouchPoint]) -> UITouch.Phase? {
        if points.contains(where: { $0.phase == .cancelled }) {
            return .cancelled
        } else if points.contains(where: { $0.phase == .ended }) {
            return .ended
        } else if points.contains(where: { $0.phase == .began }) {
            return .began
        } else if points.contains(where: { $0.phase == .moved }) {
            return .moved
        } else if points.contains(where: { $0.phase == .stationary }) {
            return .stationary
        }
        return nil
    }

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
        canvasRenderer.drawCanvasToDisplay()
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
        device: MTLDevice,
        to workingDirectoryURL: URL
    ) async throws {
        do {
            // Save the thumbnail image into the working directory
            try thumbnail(length: thumbnailLength)?.pngData()?.write(
                to: workingDirectoryURL.appendingPathComponent(CanvasView.thumbnailName)
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to create the thumbnail", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        do {
            // Copy all textures from the textureRepository
            let textures = try await canvasRenderer.textureLayersDocumentsRepository.duplicatedTextures(
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
        } catch {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to create the textures", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        do {
            // Save the texture layers as JSON
            try TextureLayersArchiveModel(
                layers: textureLayers.layers.map { .init(item: $0) },
                layerIndex: textureLayers.selectedIndex ?? 0,
                textureSize: textureLayers.textureSize
            ).write(
                in: workingDirectoryURL
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to save the texture layers", bundle: .module)
            )
            Logger.error(error)
            throw error
        }

        do {
            // Save the project metadata as JSON
            try ProjectMetaDataArchiveModel(
                projectName: projectMetaDataStorage.projectName,
                createdAt: projectMetaDataStorage.createdAt,
                updatedAt: projectMetaDataStorage.updatedAt
            ).write(
                in: workingDirectoryURL
            )
        } catch {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Failed to save the project meta data", bundle: .module)
            )
            Logger.error(error)
            throw error
        }
    }

    func projectFileName(suffix: String) -> String {
        if suffix.isEmpty {
            return projectMetaDataStorage.projectName
        } else {
            return projectMetaDataStorage.projectName + "." + suffix
        }
    }

    func thumbnail(length: CGFloat = CanvasViewModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }

    /// Returns drawing renderers ready for drawing, creating a default renderer if needed
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

    private func makeStrokePoints(
        from pointArray: [TouchPoint],
        textureSize: CGSize,
        displayTextureSize: CGSize,
        frameSize: CGSize,
        diameter: CGFloat
    ) -> [GrayscaleDotPoint] {
        pointArray.map {
            .init(
                location: CGAffineTransform.texturePoint(
                    screenPoint: $0.preciseLocation,
                    matrix: transforming.matrix.inverted(flipY: true),
                    textureSize: textureSize,
                    drawableSize: displayTextureSize,
                    frameSize: frameSize
                ),
                brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                diameter: diameter
            )
        }
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
    private func resetFingerDrawingRelatedParameters() {
        fingerStroke.reset()

        transforming.resetMatrix()

        drawingRenderer?.prepareNextStroke()

        canvasRenderer.resetCommandBuffer()
        canvasRenderer.drawCanvasToDisplay()
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

        canvasRenderer.drawCanvasToDisplay()
    }

    private func refreshCanvasAfterComposition(
        useRealtimeDrawingTexture: Bool = false
    ) {
        guard let selectedLayer = textureLayers.selectedLayer else { return }

        canvasRenderer.refreshCanvasAfterComposition(
            useRealtimeDrawingTexture: useRealtimeDrawingTexture,
            selectedLayer: .init(item: selectedLayer)
        )
    }
}
