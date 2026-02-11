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

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasViewModel` setup completes
    var setupCompletion: AnyPublisher<CanvasConfigurationResult, Never> {
        setupCompletionSubject.eraseToAnyPublisher()
    }
    private let setupCompletionSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    /// Emits drawing-related events
    var drawingEvent: AnyPublisher<DrawingEvent, Never> {
        drawingEventSubject.eraseToAnyPublisher()
    }
    private let drawingEventSubject = PassthroughSubject<DrawingEvent, Never>()

    public var currentTexture: MTLTexture?

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    private let transforming = Transforming()

    /// A class that manages drawing lines onto textures
    private var drawingRenderer: DrawingRenderer?

    /// Touch phase for drawing
    private var drawingTouchPhase: UITouch.Phase?

    /// Display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailLength: CGFloat = 500

    init(
        dependencies: CanvasViewDependencies
    ) {
        self.canvasRenderer = dependencies.canvasRenderer
    }

    func setup(
        textureSize: CGSize,
        configuration: CanvasConfiguration
    ) async throws {

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
        try await updateCanvas(textureSize)
    }
}

extension CanvasViewModel {

    func updateCanvas(_ textureSize: CGSize) async throws {

        // Update canvasRenderer using textureLayers
        try canvasRenderer.setupTextures(
            textureSize: textureSize
        )
        try await canvasRenderer.drawCanvasToDisplay()

        setupCompletionSubject.send(
            .init(
                textureSize: textureSize
            )
        )
    }
    func completeSetup(result: CanvasConfigurationResult) {
        // Update currentTextureSize
        currentTextureSize = result.textureSize

        refreshCanvas()
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
                drawingEventSubject.send(.fingerStrokeBegan)

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
            drawingEventSubject.send(.pencilStrokeBegan)

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
            let currentTexture,
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
                currentTexture: currentTexture,
                from: canvasRenderer.realtimeDrawingTexture,
                with: currentFrameCommandBuffer
            )

            currentFrameCommandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    guard
                        let `self`,
                        let currentTexture = self.currentTexture
                    else { return }

                    self.drawingEventSubject.send(
                        .strokeCompleted(texture: currentTexture)
                    )

                    // Reset parameters on drawing completion
                    self.prepareNextStroke()
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

    func resetTransforming() {
        transforming.setMatrix(.identity)
        canvasRenderer.drawCanvasToDisplay()
    }

    func setDrawingTool(_ drawingRenderer: DrawingRenderer) {
        self.drawingRenderer = drawingRenderer
        self.drawingRenderer?.prepareNextStroke()
    }

    func thumbnail(length: CGFloat = CanvasViewModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }

    func updateCurrentTexture(_ texture: MTLTexture?) {
        guard
            let currentFrameCommandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        self.canvasRenderer.drawSelectedLayerTexture(
            currentTexture: currentTexture,
            from: texture,
            with: currentFrameCommandBuffer
        )
        self.refreshCanvas()
    }

    func refreshCanvas(
        useRealtimeDrawingTexture: Bool = false
    ) {
        canvasRenderer.refreshCanvas(
            currentTexture: currentTexture,
            useRealtimeDrawingTexture: useRealtimeDrawingTexture
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
