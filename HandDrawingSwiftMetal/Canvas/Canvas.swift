//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class Canvas: TextureDisplayView {

    var currentLayer: MTLTexture {
        return layers.currentLayer
    }
    
    var commandQueue: CommandQueue!

    /// A manager of finger input and pen input.
    private let inputManager = InputManager()

    /// A manager of one finger drag or two fingers pinch.
    private let actionStateManager = ActionStateManager()


    private var drawingLayer: CanvasDrawingLayer?
    private var brushDrawingLayer: BrushDrawingLayer!
    private var eraserDrawingLayer: EraserDrawingLayer!

    private var transforming: Transforming = TransformingImpl()

    private lazy var layers: CanvasLayers = DefaultLayers(canvas: self)
    
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
        self.device = MTLCreateSystemDefaultDevice()
        let cq = self.device!.makeCommandQueue()
        assert(self.device != nil, "device is nil.")
        assert(cq != nil, "commandQueue is nil.")

        brushDrawingLayer = BrushDrawingLayer(canvas: self,
                                              drawingtoolDiameter: 8,
                                              brushColor: .black)
        eraserDrawingLayer = EraserDrawingLayer(canvas: self,
                                                drawingtoolDiameter: 32,
                                                eraserAlpha: 200)

        Pipeline.initalization(self.device!)

        commandQueue = CommandQueue(queue: cq!)

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

        layers.initalizeLayers(layerSize: textureSize)

        brushDrawingLayer.initalizeTextures(textureSize: textureSize)
        eraserDrawingLayer.initalizeTextures(textureSize: textureSize)
    }

    func inject(layers: CanvasLayers) {
        self.layers = layers
    }
    
    
    // MARK: Drawing
    func prepareForNewDrawing() {
        fingerPoints.reset()
        pencilPoints.reset()

        drawingLayer?.clear()
    }
    func refreshDisplayTexture() {
        guard let drawingLayer else { return }

        layers.flatAllLayers(currentLayer: drawingLayer.currentLayer,
                             backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                             toDisplayTexture: displayTexture)
    }
}

extension Canvas: PencilGestureRecognizerSender {
    func sendLocations(_ input: PencilGestureRecognizer?, touchLocations: [Point], touchState: TouchState) {
        guard let drawingLayer else { return }

        // Cancel drawing a line when the currentInput is the finger input.
        if inputManager.currentInput is FingerGestureRecognizer {

            fingerPoints.reset()
            matrix = transforming.storedMatrix
            prepareForNewDrawing()
        }

        if touchState == .began {
            inputManager.update(input)
        }

        pencilPoints.appendPoints(touchLocations)

        let iterator = pencilPoints.getIterator(endProcessing: touchState == .ended)
        drawingLayer.drawOnDrawingLayer(with: iterator, touchState: touchState)

        if touchState == .ended {
            drawingLayer.mergeDrawingLayerIntoCurrentLayer()
            prepareForNewDrawing()
        }

        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)

        if touchState == .ended {
            inputManager.reset()
            actionStateManager.reset()

            pencilPoints.reset()
        }
    }
    func cancel(_ gesture: PencilGestureRecognizer?) {

        prepareForNewDrawing()
    }
}

extension Canvas: FingerGestureRecognizerSender {
    func sendLocations(_ input: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState) {
        guard let drawingLayer else { return }

        if touchState == .began {
            inputManager.update(input)
        }
        guard inputManager.currentInput is FingerGestureRecognizer else { return }


        fingerPoints.appendPoints(touchLocations)

        let currentActionState = ActionState.getCurrentState(viewTouches: fingerPoints.storedPoints)
        actionStateManager.update(currentActionState)

        if actionStateManager.currentState == .drawingOnCanvas {

            let iterator = fingerPoints.getIterator(endProcessing: touchState == .ended)
            drawingLayer.drawOnDrawingLayer(with: iterator, touchState: touchState)

            if touchState == .ended {
                drawingLayer.mergeDrawingLayerIntoCurrentLayer()
                prepareForNewDrawing()
            }

            refreshDisplayTexture()
            runDisplayLinkLoop(touchState != .ended)
        }

        if actionStateManager.currentState == .transformingCanvas {
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
            inputManager.reset()
            actionStateManager.reset()

            fingerPoints.reset()
        }
    }
    func cancel(_ input: FingerGestureRecognizer?) {
        guard inputManager.currentInput is FingerGestureRecognizer else { return }

        prepareForNewDrawing()
    }
}

extension Canvas {
    var drawingTool: DrawingTool {
        get {
            if drawingLayer is EraserDrawingLayer {
                return .eraser
            } else {
                return .brush
            }
        }
        set {
            if newValue == .eraser {
                drawingLayer = eraserDrawingLayer
            } else {
                drawingLayer = brushDrawingLayer
            }
        }
    }

    var brushDiameter: Int {
        brushDrawingLayer.brush.diameter
    }
    func setBrushDiameter(_ diameter: Int) {
        brushDrawingLayer.brush.diameter = diameter
    }
    func setBrushColor(_ color: UIColor) {
        brushDrawingLayer.brush.setValue(color: color)
    }

    var eraserDiameter: Int {
        eraserDrawingLayer.eraser.diameter
    }
    func setEraserDiameter(_ diameter: Int) {
        eraserDrawingLayer.eraser.diameter = diameter
    }
    func setEraserAlpha(_ alpha: Int) {
        eraserDrawingLayer.eraser.setValue(alpha: alpha)
    }

    func clear() {
        layers.clear()
        refreshDisplayTexture()
    }

    func resetMatrix() {
        matrix = CGAffineTransform.identity
        transforming.storedMatrix = matrix
    }
}
