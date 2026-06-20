//
//  CanvasViewModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import UIKit

/// A view model that manages canvas rendering and texture layers.
@MainActor
final class CanvasViewModel {

    /// The frame size, which changes when the screen rotates or the view layout updates.
    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.setFrameSize(frameSize)
        }
    }

    /// Texture to be drawn. Writable because only `CanvasView` assigns it from outside.
    var currentTexture: MTLTexture?

    /// Emits when a stroke session was committed.
    let strokeSessionDidCommitSubject = PassthroughSubject<Void, Never>()

    /// Emits canvas events.
    let canvasEventSubject = PassthroughSubject<CanvasEvent, Never>()

    /// Owns finger and pencil stroke lifecycle transitions.
    let strokeLifecycle = StrokeLifecycleManager()

    /// Owns canvas pan/pinch lifecycle transitions.
    let transformLifecycle = TransformLifecycleManager()

    /// The size of the texture currently set on the canvas.
    /// A temporary value is assigned to avoid making it optional.
    private(set) var currentTextureSize: CGSize = .init(width: 768, height: 1024)

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    /// Texture that combines the background color and the textures of `currentTexture`
    private(set) var canvasTexture: MTLTexture?

    /// A class that manages rendering to the canvas
    private let canvasRenderer: CanvasRenderer

    /// A class that manages drawing lines onto textures
    private(set) var drawingRenderer: HighPrecisionDrawingRenderer?

    /// Manages input from pen and finger
    private let inputState = InputState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGestureState = TouchGestureState()

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()

    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    private let transforming = Transforming()

    init(
        canvasRenderer: CanvasRenderer,
        configuration: CanvasConfiguration
    ) {
        self.canvasRenderer = canvasRenderer

        // Set the gesture recognition durations in seconds
        self.touchGestureState.setDrawingGestureRecognitionSecond(
            configuration.drawingGestureRecognitionSecond
        )
        self.touchGestureState.setTransformingGestureRecognitionSecond(
            configuration.transformingGestureRecognitionSecond
        )

        self.currentTextureSize = configuration.textureSize
    }

    func initializeCanvas(_ textureSize: CGSize) async throws {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        guard
            let canvasTexture = canvasRenderer.makeTexture(textureSize),
            let currentTexture = canvasRenderer.makeTexture(textureSize),
            let realtimeDrawingTexture = canvasRenderer.makeTexture(textureSize)
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(localized: "Unable to create canvas textures")
            )
            Logger.error(error)
            throw error
        }

        self.canvasTexture = canvasTexture
        self.currentTexture = currentTexture
        self.realtimeDrawingTexture = realtimeDrawingTexture
        self.currentTextureSize = textureSize
    }
}

extension CanvasViewModel {
    /// Processes finger touches and determines whether the gesture is drawing or transforming
    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard inputState.isNotPencil else { return }
        inputState.update(.finger)

        fingerStroke.appendTouchPointToDictionary(
            UITouch.fingerTouchesOnScreen(touches: touches, from: event, on: view)
        )

        // determine the gesture from the dictionary
        switch touchGestureState.update(fingerStroke.touchHistories) {
        case .undetermined: break
        case .drawing: fingerDraw()
        case .transforming: transformCanvas()
        }

        // Remove unused finger arrays from the dictionary
        fingerStroke.removeUnusedTouchArrayFromDictionary()

        if UITouch.isAllFingersReleasedFromScreen(event: event, touches: touches) {
            resetAfterAllFingersReleased()
        }
    }

    /// Processes pencil input using estimated touches
    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        if inputState.isFinger {
            resetFingerDrawing()
            present()
        }
        inputState.update(.pencil)

        // Stores the latest estimated pencil touch for stroke-end detection.
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
        pencilDraw(actualTouches: actualTouches, view: view)
    }

    func onResetTransforming() {
        resetTransforming()
    }

    /// Renders the active stroke into the realtime texture.
    func onRenderRealtimeDrawingTexture() {
        renderRealtimeStrokeSession()
    }
}

private extension CanvasViewModel {
    func fingerDraw() {
        guard
            let drawingRenderer,
            let displayTextureSize = canvasRenderer.displayTextureSize
        else { return }

        switch strokeLifecycle.phase {
        case .idle:
            strokeLifecycle.beginIfIdle()
            fingerStroke.setDrawingTouchID()
            drawingRenderer.setStrokeCurveScale(transforming.matrix.uniformLinearScale)
            drawingRenderer.beginFingerStroke()
            fallthrough

        case .drawing:
            let pointArray = fingerStroke.drawingPoints(
                after: fingerStroke.lastDrawnTouchPoint
            )

            drawingRenderer.appendStrokePoints(
                strokePoints: pointArray.map {
                    .init(
                        location: CGAffineTransform.texturePoint(
                            screenPoint: $0.preciseLocation,
                            matrix: transforming.matrix.inverted(flipY: true),
                            textureSize: currentTextureSize,
                            drawableSize: displayTextureSize,
                            frameSize: frameSize
                        ),
                        brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                        diameter: CGFloat(drawingRenderer.diameter)
                    )
                },
                touchPhase: pointArray.currentTouchPhase
            )

            fingerStroke.setLastDrawnTouchPoint()

            if fingerStroke.shouldFinalizeDrawing(from: pointArray) {
                strokeLifecycle.finalizeIfDrawing(cancelled: fingerStroke.isCancelled)
                fallthrough
            }

        case .finalizing:
            commitRealtimeStrokeSession()
        }
    }

    func pencilDraw(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        guard
            let drawingRenderer,
            let displayTextureSize = canvasRenderer.displayTextureSize
        else { return }

        switch strokeLifecycle.phase {
        case .idle:
            guard actualTouches.contains(where: { $0.phase == .began }) else { return }

            strokeLifecycle.beginIfIdle()
            drawingRenderer.setStrokeCurveScale(transforming.matrix.uniformLinearScale)
            drawingRenderer.beginPencilStroke()
            fallthrough

        case .drawing:
            pencilStroke.appendActualTouches(
                actualTouches: actualTouches
                    .sorted { $0.timestamp < $1.timestamp }
                    .map { .init(touch: $0, view: view) }
            )

            let pointArray = pencilStroke.drawingPoints(after: pencilStroke.lastDrawnTouchPoint)

            drawingRenderer.appendStrokePoints(
                strokePoints: pointArray.map {
                    .init(
                        location: CGAffineTransform.texturePoint(
                            screenPoint: $0.preciseLocation,
                            matrix: transforming.matrix.inverted(flipY: true),
                            textureSize: currentTextureSize,
                            drawableSize: displayTextureSize,
                            frameSize: frameSize
                        ),
                        brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                        diameter: CGFloat(drawingRenderer.diameter)
                    )
                },
                touchPhase: pointArray.currentTouchPhase
            )
            pencilStroke.setLastDrawnTouchPoint()

            if pencilStroke.shouldFinalizeDrawing(from: pointArray) {
                strokeLifecycle.finalizeIfDrawing(
                    cancelled: pointArray.last?.phase == .cancelled
                )
                fallthrough
            }

        case .finalizing:
            commitRealtimeStrokeSession()
        }
    }

    func transformCanvas() {
        switch transformLifecycle.phase {
        case .idle:
            transformLifecycle.beginIfIdle()
            transforming.initialize(fingerStroke.touchHistories)
            fallthrough

        case .transforming:
            guard fingerStroke.hasActiveTouches else {
                transformLifecycle.finalizeIfTransforming()
                fallthrough
            }

            transforming.transformCanvas(
                screenCenter: .init(
                    x: frameSize.width * 0.5,
                    y: frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )

            present()

        case .finalizing:
            transforming.endTransformation()
            transformLifecycle.complete()

            present()
        }
    }
}

private extension CanvasViewModel {
    /// Renders the active stroke into the realtime texture.
    func renderRealtimeStrokeSession() {
        guard case .drawing = strokeLifecycle.phase else { return }

        guard
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

        // Keep showing `currentTexture` until the first successful draw copies the base
        // into the realtime texture. Otherwise an empty realtime texture flashes on screen.
        guard drawingRenderer.hasDrawnToRealtimeTexture else { return }

        canvasEventSubject.send(.displayRealtimeDrawingTexture)
    }

    /// Renders the final stroke into the realtime texture,
    /// merges the realtime texture into the current texture, and ends the session.
    func commitRealtimeStrokeSession() {
        guard case .finalizing(cancelled: let cancelled) = strokeLifecycle.phase else { return }

        guard
            let drawingRenderer,
            let currentTexture,
            let realtimeDrawingTexture,
            let commandBuffer = canvasRenderer.currentFrameCommandBuffer
        else { return }

        if cancelled {
            canvasEventSubject.send(.displayCurrentTexture)
            finishStrokeSession(commandBuffer: canvasRenderer.currentFrameCommandBuffer)
            return
        }

        drawingRenderer.drawStroke(
            baseTexture: currentTexture,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        if drawingRenderer.hasDrawnToRealtimeTexture {
            canvasRenderer.applyRealtimeDrawingTexture(
                realtimeDrawingTexture,
                to: currentTexture,
                with: commandBuffer
            )

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.strokeSessionDidCommitSubject.send()
                }
            }
        }

        canvasEventSubject.send(.displayCurrentTexture)
        finishStrokeSession(commandBuffer: commandBuffer)
    }

    /// Resets session state after a drawing stroke is committed.
    func finishStrokeSession(commandBuffer: MTLCommandBuffer?) {
        strokeLifecycle.complete()
        resetAfterDrawingStroke()
        drawingRenderer?.prepareNextStroke(with: commandBuffer)
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

    func updateDrawingRenderer(_ drawingRenderer: HighPrecisionDrawingRenderer) {
        self.drawingRenderer = drawingRenderer
        self.drawingRenderer?.prepareNextStroke()
    }

    func updateCanvasTexture(_ texture: MTLTexture?) {
        canvasRenderer.updateCanvasTexture(
            currentTexture: texture,
            canvasTexture: canvasTexture
        )
    }
}

private extension CanvasViewModel {
    /// Resets input, touch history, and lifecycles after a drawing stroke is committed.
    func resetAfterDrawingStroke() {
        inputState.reset()
        touchGestureState.reset()

        pencilStroke.reset()
        fingerStroke.reset()
        strokeLifecycle.reset()

        transforming.resetMatrix()
        transformLifecycle.reset()
    }

    /// Resets finger-session state after every finger has left the screen.
    /// Only runs while `inputState` is not `.pencil`.
    func resetAfterAllFingersReleased() {
        if drawingRenderer?.hasDrawnToRealtimeTexture == true {
            drawingRenderer?.prepareNextStroke()
        }

        inputState.reset()
        touchGestureState.reset()

        fingerStroke.reset()
        strokeLifecycle.reset()

        transforming.resetMatrix()
        transformLifecycle.reset()
    }

    /// Resets in-progress finger drawing when Apple Pencil input takes over.
    func resetFingerDrawing() {
        drawingRenderer?.prepareNextStroke()
        canvasRenderer.resetCommandBuffer()

        fingerStroke.reset()

        transforming.resetMatrix()
        transformLifecycle.reset()
    }

    /// Resets the canvas transform to identity.
    func resetTransforming() {
        transforming.setMatrix(.identity)
        transformLifecycle.reset()

        present()
    }
}
