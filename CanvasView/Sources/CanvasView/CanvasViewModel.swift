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
        drawingTouchPhaseSubject.value == .ended
    }
    private var isCancelledDrawing: Bool {
        drawingTouchPhaseSubject.value == .cancelled
    }

    /// A publisher that emits `CGSize` when the canvas size changes
    var canvasSizeDidChange: AnyPublisher<CGSize, Never> {
        canvasSizeDidChangeSubject.eraseToAnyPublisher()
    }
    private let canvasSizeDidChangeSubject = PassthroughSubject<CGSize, Never>()

    /// Emits drawing-related events
    var drawingEvent: AnyPublisher<DrawingEvent, Never> {
        drawingEventSubject.eraseToAnyPublisher()
    }
    private let drawingEventSubject = PassthroughSubject<DrawingEvent, Never>()

    var drawingTouchPhase: AnyPublisher<UITouch.Phase?, Never> {
        drawingTouchPhaseSubject.eraseToAnyPublisher()
    }
    private let drawingTouchPhaseSubject = CurrentValueSubject<UITouch.Phase?, Never>(nil)

    var currentTextureDisplaying: AnyPublisher<Void, Never> {
        currentTextureDisplayingSubject.eraseToAnyPublisher()
    }
    private let currentTextureDisplayingSubject = PassthroughSubject<Void, Never>()

    var realtimeDrawingTextureDisplaying: AnyPublisher<Void, Never> {
        realtimeDrawingTextureDisplayingSubject.eraseToAnyPublisher()
    }
    private let realtimeDrawingTextureDisplayingSubject = PassthroughSubject<Void, Never>()

    public var displayRealtimeDrawingTexture: Bool {
        drawingRenderer?.displayRealtimeDrawingTexture ?? false
    }

    private(set) var currentTexture: MTLTexture?

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// Manages input from pen and finger
    private let deviceInput = DeviceInputState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    private let transforming = Transforming()

    /// A class that manages drawing lines onto textures
    private var drawingRenderer: DrawingRenderer?

    private var cancellables = Set<AnyCancellable>()

    init(
        canvasRenderer: CanvasRenderer
    ) {
        self.canvasRenderer = canvasRenderer
    }

    func setup(
        configuration: CanvasConfiguration
    ) async throws {

        bindData()

        canvasRenderer.setup(
            backgroundColor: configuration.backgroundColor,
            baseBackgroundColor: configuration.baseBackgroundColor
        )
        setupTouchGesture(
            drawingGestureRecognitionSecond: configuration.drawingGestureRecognitionSecond,
            transformingGestureRecognitionSecond: configuration.transformingGestureRecognitionSecond
        )

        try resizeCanvas(configuration.textureSize)
    }
}

extension CanvasViewModel {

    func resizeCanvas(_ textureSize: CGSize) throws {

        // Update canvasRenderer using textureLayers
        try canvasRenderer.initializeTextures(
            textureSize: textureSize
        )

        currentTexture = canvasRenderer.makeTexture(
            textureSize,
            label: "currentTexture"
        )

        realtimeDrawingTexture = canvasRenderer.makeTexture(
            textureSize,
            label: "realtimeDrawingTexture"
        )

        // Update currentTextureSize
        currentTextureSize = textureSize

        canvasSizeDidChangeSubject.send(textureSize)
    }
}

extension CanvasViewModel {

    private func bindData() {
        // Avoid multiple subscriptions
        cancellables.removeAll()

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
        deviceInput.update(.finger)

        // Return if a pen input is in progress
        guard deviceInput.isNotPencil else { return }

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

            // Update the touch phase for drawing
            drawingTouchPhaseSubject.send(
                drawingTouchPhase(pointArray)
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
        if deviceInput.isFinger {
            resetFingerDrawingRelatedParameters()
        }
        deviceInput.update(.pencil)

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

        // Update the touch phase for drawing
        drawingTouchPhaseSubject.send(
            drawingTouchPhase(pointArray)
        )
    }

    /// Called on every display-link frame while drawing is active
    func onDrawingDisplayLinkFrame() {
        guard
            touchGesture.state == .drawing,
            let drawingRenderer,
            let currentTexture,
            let realtimeDrawingTexture,
            let commandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        drawingRenderer.drawStroke(
            baseTexture: currentTexture,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        // The finalization process is performed when drawing is completed
        if isFinishedDrawing {
            canvasRenderer.applyTexture(
                realtimeDrawingTexture,
                to: currentTexture,
                with: commandBuffer
            )

            // Reset parameters on drawing completion
            prepareNextStroke(commandBuffer: commandBuffer)

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    guard let currentTexture = self?.currentTexture else { return }
                    self?.drawingEventSubject.send(
                        .strokeCompleted(texture: currentTexture)
                    )
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke(commandBuffer: commandBuffer)
        }

        if displayRealtimeDrawingTexture {
            realtimeDrawingTextureDisplayingSubject.send()
        } else {
            currentTextureDisplayingSubject.send()
        }
    }

    func drawCanvasToDisplay() {
        canvasRenderer.drawCanvasToDisplay()
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

    func setCurrentTexture(_ texture: MTLTexture?) throws {
        guard
            let texture,
            Int(texture.width) >= canvasMinimumTextureLength &&
            Int(texture.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(
                    localized: "Texture size is below the minimum: \(texture?.width ?? 0) \(texture?.height ?? 0)",
                    bundle: .module
                )
            )
            Logger.error(error)
            throw error
        }
        self.currentTexture = texture
    }

    func updateCanvasTextureUsingRealtimeDrawingTexture() {
        updateCanvasTexture(using: realtimeDrawingTexture)
    }
    func updateCanvasTexture(
        using texture: MTLTexture? = nil
    ) {
        canvasRenderer.updateCanvasTexture(
            currentTexture: texture ?? currentTexture,
            canvasTexture: canvasRenderer.canvasTexture
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

    private func prepareNextStroke(commandBuffer: MTLCommandBuffer) {
        deviceInput.reset()
        touchGesture.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        transforming.resetMatrix()

        drawingTouchPhaseSubject.send(nil)

        drawingRenderer?.prepareNextStroke(with: commandBuffer)
    }

    private func resetFingerGestureParameters() {
        touchGesture.reset()

        fingerStroke.reset()

        drawingTouchPhaseSubject.send(nil)
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
