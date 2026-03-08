//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import UIKit

/// A view model that manages canvas rendering and texture layers.
@MainActor
public final class CanvasViewModel {

    /// The frame size, which changes when the screen rotates or the view layout updates.
    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.setFrameSize(frameSize)
        }
    }

    /// Publishes stroke events
    let strokeEventSubject = PassthroughSubject<StrokeEvent, Never>()

    /// Publishes canvas events
    let canvasEventSubject = PassthroughSubject<CanvasEvent, Never>()

    /// Publishes the current touch phase during a drawing interaction
    let drawingTouchPhaseSubject = CurrentValueSubject<UITouch.Phase?, Never>(nil)

    /// The size of the texture currently set on the canvas.
    /// A temporary value is assigned to avoid making it optional.
    private(set) var currentTextureSize: CGSize = .init(width: 768, height: 1024)

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    /// Texture to be drawn
    private(set) var currentTexture: MTLTexture?

    /// Texture that combines the background color and the textures of `currentTexture`
    private(set) var canvasTexture: MTLTexture?

    /// A class that manages rendering to the canvas
    private let canvasRenderer: CanvasRenderer

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    private var isFinishedDrawing: Bool {
        drawingTouchPhaseSubject.value == .ended
    }
    private var isCancelledDrawing: Bool {
        drawingTouchPhaseSubject.value == .cancelled
    }

    private var displayRealtimeDrawingTexture: Bool {
        drawingRenderer?.displayRealtimeDrawingTexture ?? false
    }

    /// Manages input from pen and finger
    private let inputState = InputState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    private let transforming = Transforming()

    /// A class that manages drawing lines onto textures
    private var drawingRenderer: DrawingRenderer?

    init(
        canvasRenderer: CanvasRenderer
    ) {
        self.canvasRenderer = canvasRenderer
    }

    func setup(
        _ configuration: CanvasConfiguration
    ) {
        canvasRenderer.setup(
            backgroundColor: configuration.backgroundColor,
            baseBackgroundColor: configuration.baseBackgroundColor
        )
        setupTouchGesture(
            drawingGestureRecognitionSecond: configuration.drawingGestureRecognitionSecond,
            transformingGestureRecognitionSecond: configuration.transformingGestureRecognitionSecond
        )

        createCanvas(configuration.textureSize)

        present()
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

    /// Presents `canvasTexture` to the screen
    func present() {
        canvasRenderer.drawCanvasTextureToDisplay(
            matrix: transforming.matrix,
            canvasTexture: canvasTexture
        )
    }

    func createCanvas(_ textureSize: CGSize) {

        canvasTexture = canvasRenderer.makeTexture(
            textureSize,
            label: "canvasTexture"
        )
        currentTexture = canvasRenderer.makeTexture(
            textureSize,
            label: "currentTexture"
        )
        realtimeDrawingTexture = canvasRenderer.makeTexture(
            textureSize,
            label: "realtimeDrawingTexture"
        )

        currentTextureSize = textureSize

        canvasEventSubject.send(
            .canvasCreated(textureSize)
        )
    }

    func setCurrentTexture(_ texture: MTLTexture?) {
        self.currentTexture = texture
    }

    func setDrawingRenderer(_ drawingRenderer: DrawingRenderer) {
        self.drawingRenderer = drawingRenderer
        self.drawingRenderer?.prepareNextStroke()
    }

    func updateCanvasTexture(_ texture: MTLTexture?) {
        canvasRenderer.updateCanvasTexture(
            currentTexture: texture,
            canvasTexture: canvasTexture
        )
    }

    func resetTransforming() {
        transforming.setMatrix(.identity)
        present()
    }
}

extension CanvasViewModel {

    /// Processes finger touches and determines whether the gesture is drawing or transforming
    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        inputState.update(.finger)

        // Return if a pen input is in progress
        guard inputState.isNotPencil else { return }

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
                let displayTextureSize = canvasRenderer.displayTextureSize
            else { return }

            // Execute if finger drawing has not yet started
            if fingerStroke.isFingerDrawingInactive {
                strokeEventSubject.send(.fingerStrokeBegan)

                // Store the drawing-specific key in the dictionary
                fingerStroke.setStoreKeyForDrawing()

                drawingRenderer.beginFingerStroke()
            }

            let pointArray = fingerStroke.drawingPoints(after: fingerStroke.drawingLineEndPoint)

            drawingRenderer.appendStrokePoints(
                strokePoints: makeStrokePoints(
                    from: pointArray,
                    textureSize: currentTextureSize,
                    displayTextureSize: displayTextureSize,
                    frameSize: frameSize,
                    diameter: CGFloat(drawingRenderer.diameter)
                ),
                touchPhase: pointArray.currentTouchPhase
            )

            fingerStroke.updateDrawingLineEndPoint()

            // Update the touch phase for drawing
            drawingTouchPhaseSubject.send(
                TouchPhase.drawingTouchPhase(pointArray)
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
        if inputState.isFinger {
            cancelFingerDrawing()
        }
        inputState.update(.pencil)

        touchGesture.setDrawing()

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
            let displayTextureSize = canvasRenderer.displayTextureSize
        else { return }

        // Execute if it’s the beginning of a touch
        if actualTouches.contains(where: { $0.phase == .began }) {
            strokeEventSubject.send(.pencilStrokeBegan)

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
                textureSize: currentTextureSize,
                displayTextureSize: displayTextureSize,
                frameSize: frameSize,
                diameter: CGFloat(drawingRenderer.diameter)
            ),
            touchPhase: pointArray.currentTouchPhase
        )
        pencilStroke.setDrawingLineEndPoint()

        // Update the touch phase for drawing
        drawingTouchPhaseSubject.send(
            TouchPhase.drawingTouchPhase(pointArray)
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
            canvasRenderer.applyRealtimeDrawingTexture(
                realtimeDrawingTexture,
                to: currentTexture,
                with: commandBuffer
            )

            // Reset parameters on drawing completion
            prepareNextStroke(commandBuffer: commandBuffer)

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.strokeEventSubject.send(.strokeCompleted)
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke(commandBuffer: commandBuffer)
            strokeEventSubject.send(.strokeCancelled)
        }

        canvasEventSubject.send(
            displayRealtimeDrawingTexture ? .displayRealtimeDrawingTexture: .displayCurrentTexture
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
        inputState.reset()
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

    private func cancelFingerDrawing() {
        fingerStroke.reset()

        transforming.resetMatrix()

        drawingRenderer?.prepareNextStroke()

        canvasRenderer.resetCommandBuffer()

        present()
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

        present()
    }
}
