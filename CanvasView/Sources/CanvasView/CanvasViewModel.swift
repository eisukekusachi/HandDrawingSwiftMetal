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

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasViewModel` setup completes
    var setupCompletion: AnyPublisher<CanvasConfigurationResult, Never> {
        setupCompletionSubject.eraseToAnyPublisher()
    }
    private let setupCompletionSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    var fingerDrawingDidBegin: AnyPublisher<Void, Never> {
        fingerDrawingDidBeginSubject.eraseToAnyPublisher()
    }
    private let fingerDrawingDidBeginSubject = PassthroughSubject<Void, Never>()

    var pencilDrawingDidBegin: AnyPublisher<Void, Never> {
        pencilDrawingDidBeginSubject.eraseToAnyPublisher()
    }
    private let pencilDrawingDidBeginSubject = PassthroughSubject<Void, Never>()

    /// A publisher that emits `Void` when drawing completes
    var drawingCompletion: AnyPublisher<Void, Never> {
        drawingCompletionSubject.eraseToAnyPublisher()
    }
    private let drawingCompletionSubject = PassthroughSubject<Void, Never>()

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    /// Undoable texture layers
    private var textureLayers: UndoTextureLayers?

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

    private var textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailLength: CGFloat = 500

    init(
        dependencies: CanvasViewDependencies
    ) {
        self.canvasRenderer = dependencies.canvasRenderer
    }

    func setup(
        textureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?,
        textureLayersState: TextureLayersState?,
        drawingRenderers: [DrawingRenderer] = [],
        configuration: CanvasConfiguration
    ) async throws {
        self.textureLayers = textureLayers
        self.textureLayersDocumentsRepository = textureLayersDocumentsRepository
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
            textureLayersState: textureLayersState,
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
        textureLayersState: TextureLayersState
    ) async throws {
        guard let textureLayers else { return }

        // Restore the repository using TextureLayersState
        try await textureLayersDocumentsRepository?.restoreStorageFromSavedData(
            url: workingDirectoryURL,
            textureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        setupCompletionSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }

    func completeSetup(result: CanvasConfigurationResult) {
        // Update the thumbnails
        Task { [weak self] in
            for layer in result.textureLayers.layers {
                try await self?.textureLayers?.updateThumbnail(layer.id)
            }
        }

        // Update currentTextureSize
        currentTextureSize = result.textureSize

        refreshCanvas()
    }

    func updateCurrentTexture(_ texture: MTLTexture?) {
        guard
            let currentFrameCommandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        self.canvasRenderer.drawSelectedLayerTexture(
            from: texture,
            with: currentFrameCommandBuffer
        )
        self.refreshCanvas()
    }

    func updateCurrentTextureUsingRepository() {
        guard
            let textureLayers = self.textureLayers,
            let context = CanvasTextureLayersContext(textureLayers: textureLayers)
        else { return }
        Task {
            try await self.canvasRenderer.refreshTexturesFromRepository(
                repository: self.textureLayersDocumentsRepository,
                context: context
            )
            self.refreshCanvas()
        }
    }
}

extension CanvasViewModel {

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.update
            .sink { [weak self] in
                self?.onDrawingDisplayLinkFrame()
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer.setMatrix(matrix)
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
        textureLayersState: TextureLayersState
    ) async throws {
        guard let textureLayers else { return }

        // Initialize the repository using TextureLayersState
        try await textureLayersDocumentsRepository?.initializeStorage(
            newTextureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        setupCompletionSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }

    private func setupCanvasFromCoreData(
        textureLayersState: TextureLayersState
    ) async throws {
        guard let textureLayers else { return }

        // Restore the repository using TextureLayersState
        try textureLayersDocumentsRepository?.restoreStorageFromCoreData(
            textureLayersState: textureLayersState
        )

        try await setupCanvasRenderer(textureLayersState: textureLayersState)

        setupCompletionSubject.send(
            .init(
                textureSize: textureLayersState.textureSize,
                textureLayers: textureLayers
            )
        )
    }

    /// Sets up `CanvasRenderer` with updated `textureLayers`
    private func setupCanvasRenderer(textureLayersState: TextureLayersState) async throws {
        guard let textureLayers else { return }

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
            repository: textureLayersDocumentsRepository,
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
                fingerDrawingDidBeginSubject.send()

                // Store the drawing-specific key in the dictionary
                fingerStroke.setStoreKeyForDrawing()

                drawingRenderer.beginFingerStroke()
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
            pencilDrawingDidBeginSubject.send()

            drawingRenderer.beginPencilStroke()
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
            let currentTexture = canvasRenderer.currentTexture,
            let realtimeDrawingTexture = canvasRenderer.realtimeDrawingTexture,
            let currentFrameCommandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        drawingRenderer.drawStroke(
            baseTexture: currentTexture,
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
                    self?.drawingCompletionSubject.send()

                    // Reset parameters on drawing completion
                    self?.prepareNextStroke()

                    self?.onCompleteDrawing()
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke()
        }

        refreshCanvas(
            useRealtimeDrawingTexture: drawingRenderer.displayRealtimeDrawingTexture
        )
    }

    /// Called when a stroke is completed
    private func onCompleteDrawing() {
        guard
            let textureLayers,
            let layerId = textureLayers.selectedLayer?.id,
            let currentTexture = canvasRenderer.currentTexture
        else { return }

        drawingDebouncer.perform { [weak self] in
            Task(priority: .utility) { [weak self] in
                guard
                    let self
                else { return }
                do {
                    try await self.textureLayersDocumentsRepository?.writeTextureToDisk(
                        texture: currentTexture,
                        for: layerId
                    )

                    self.textureLayers?.updateThumbnail(
                        layerId,
                        texture: currentTexture
                    )

                } catch {
                    Logger.error(error)
                }
            }
        }
    }

    /// Called when the display texture size changes, such as when the device orientation changes
    func onUpdateDisplayTexture() {
        refreshCanvas()
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
        textureSize: CGSize
    ) async throws {
        try await setupDefaultCanvas(
            textureLayersState: TextureLayersState(textureSize: textureSize)
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

    func thumbnail(length: CGFloat = CanvasViewModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }

    func refreshCanvas(
        useRealtimeDrawingTexture: Bool = false
    ) {
        guard let selectedLayer = textureLayers?.selectedLayer else { return }

        canvasRenderer.refreshCanvas(
            useRealtimeDrawingTexture: useRealtimeDrawingTexture,
            selectedLayer: .init(item: selectedLayer)
        )
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
}
