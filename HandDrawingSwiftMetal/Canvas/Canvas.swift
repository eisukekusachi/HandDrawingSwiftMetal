//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class Canvas: TextureDisplayView {

    var currentTexture: MTLTexture {
        return layers.currentTexture
    }

    /// A manager of finger input and pen input.
    private let gestureManager = GestureManager()

    /// A manager of one finger drag or two fingers pinch.
    private let actionStateManager = ActionStateManager()

    private var drawingTexture: DrawingTextureProtocol?
    private var brushDrawingTexture: BrushDrawingTexture!
    private var eraserDrawingTexture: EraserDrawingTexture!

    private var transforming: Transforming = TransformingImpl()

    private lazy var layers: LayerManagerProtocol = LayerManager(canvas: self)

    private lazy var fingerInput = FingerGestureRecognizer(output: self)
    private lazy var pencilInput = PencilGestureRecognizer(output: self)

    private var pencilPoints = DefaultPointStorage()
    private var fingerPoints = SmoothPointStorage()

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        brushDrawingTexture = BrushDrawingTexture(canvas: self)
        eraserDrawingTexture = EraserDrawingTexture(canvas: self)

        _ = Pipeline.shared

        addGestureRecognizer(fingerInput)
        addGestureRecognizer(pencilInput)
    }

    override func layoutSubviews() {
        if  let drawableSize = currentDrawable?.texture.size,
                displayTexture == nil {
            
            initalizeTextures(textureSize: drawableSize)
        }

        refreshDisplayTexture()
        setNeedsDisplay()
    }
    
    func initalizeTextures(textureSize: CGSize) {
        super.initializeTextures(textureSize: textureSize)

        layers.initalizeTextures(textureSize: textureSize)

        brushDrawingTexture.initalizeTextures(textureSize: textureSize)
        eraserDrawingTexture.initalizeTextures(textureSize: textureSize)
    }

    func inject(layers: LayerManagerProtocol) {
        self.layers = layers
    }
    
    
    // MARK: Drawing
    func prepareForNewDrawing() {
        fingerPoints.reset()
        pencilPoints.reset()

        drawingTexture?.clearDrawingTextures()
    }
    func refreshDisplayTexture() {
        guard let drawingTexture else { return }

        layers.mergeAllTextures(currentTextures: drawingTexture.currentTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: displayTexture)
    }
    private func cancelFingerDrawing() {
        drawingTexture?.clearDrawingTextures()

        fingerPoints.reset()
        transforming.storedMatrix = matrix
    }
}

extension Canvas: PencilGestureRecognizerSender {
    func sendLocations(_ input: PencilGestureRecognizer?, touchLocations: [TouchPoint], touchState: TouchState) {
        guard let drawingTexture else { return }

        // Cancel drawing a line when the currentInput is the finger input.
        if gestureManager.currentGesture is FingerGestureRecognizer {
            cancelFingerDrawing()
        }

        if touchState == .began {
            gestureManager.update(input!)
        }

        pencilPoints.appendPoints(touchLocations)

        let iterator = pencilPoints.getIterator(endProcessing: touchState == .ended)
        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)

        if touchState == .ended {
            drawingTexture.mergeDrawingTexture(into: currentTexture)
            prepareForNewDrawing()
        }

        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)

        if touchState == .ended {
            gestureManager.reset()
            actionStateManager.reset()

            pencilPoints.reset()
        }
    }
    func cancel(_ gesture: PencilGestureRecognizer?) {

        prepareForNewDrawing()
    }
}

extension Canvas: FingerGestureRecognizerSender {
    func sendLocations(_ input: FingerGestureRecognizer?, touchLocations: [Int: TouchPoint], touchState: TouchState) {
        guard let drawingTexture else { return }

        if touchState == .began {
            gestureManager.update(input!)
        }
        guard gestureManager.currentGesture is FingerGestureRecognizer else { return }


        fingerPoints.appendPoints(touchLocations)

        let currentActionState = ActionStateManager.getState(touchPoints: fingerPoints.storedPoints)
        actionStateManager.update(currentActionState)

        if actionStateManager.state == .drawingOnCanvas {

            let iterator = fingerPoints.getIterator(endProcessing: touchState == .ended)
            drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)

            if touchState == .ended {
                drawingTexture.mergeDrawingTexture(into: currentTexture)
                prepareForNewDrawing()
            }

            refreshDisplayTexture()
            runDisplayLinkLoop(touchState != .ended)
        }

        if actionStateManager.state == .transformingCanvas {
            if let matrix = transforming.update(viewTouches: fingerPoints.storedPoints,
                                                viewSize: frame.size) {
                self.matrix = matrix
            }

            if touchState == .ended {
                transforming.endTransforming(matrix)
            }

            setNeedsDisplay()
        }

        if touchState == .ended {
            gestureManager.reset()
            actionStateManager.reset()

            fingerPoints.reset()
        }
    }
    func cancel(_ input: FingerGestureRecognizer?) {
        guard gestureManager.currentGesture is FingerGestureRecognizer else { return }

        prepareForNewDrawing()
    }
}

extension Canvas {
    var drawingTool: DrawingTool {
        get {
            if drawingTexture is EraserDrawingTexture {
                return .eraser
            } else {
                return .brush
            }
        }
        set {
            if newValue == .eraser {
                drawingTexture = eraserDrawingTexture
            } else {
                drawingTexture = brushDrawingTexture
            }
        }
    }

    var brushDiameter: Int {
        brushDrawingTexture.brush.diameter
    }
    func setBrushDiameter(_ diameter: Int) {
        brushDrawingTexture.brush.diameter = diameter
    }
    func setBrushColor(_ color: UIColor) {
        brushDrawingTexture.brush.setValue(color: color)
    }

    var eraserDiameter: Int {
        eraserDrawingTexture.eraser.diameter
    }
    func setEraserDiameter(_ diameter: Int) {
        eraserDrawingTexture.eraser.diameter = diameter
    }
    func setEraserAlpha(_ alpha: Int) {
        eraserDrawingTexture.eraser.setValue(alpha: alpha)
    }

    func clear() {
        layers.clearTexture()
        refreshDisplayTexture()
    }

    func resetMatrix() {
        matrix = CGAffineTransform.identity
        transforming.storedMatrix = matrix
    }
}
