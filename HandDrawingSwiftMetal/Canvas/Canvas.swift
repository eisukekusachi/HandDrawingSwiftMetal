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

    private var drawingTexture: DrawingTextureProtocol?
    private var brushDrawingTexture: BrushDrawingTexture!
    private var eraserDrawingTexture: EraserDrawingTexture!

    private var transforming: Transforming = Transforming()

    private lazy var layers: LayerManagerProtocol = LayerManager(canvas: self)

    /// A manager of finger input and pen input.
    private var gestureManager: GestureManager!

    private var fingerGesture: FingerGesture!
    private var pencilGesture: PencilGesture!

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

        gestureManager = GestureManager()
        fingerGesture = FingerGesture(view: self, delegate: self)
        pencilGesture = PencilGesture(view: self, delegate: self)
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
    func refreshDisplayTexture() {
        guard let drawingTexture else { return }

        layers.mergeAllTextures(currentTextures: drawingTexture.currentTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: displayTexture)
    }
    private func cancelFingerDrawing() {
        fingerGesture.clear()
        transforming.storedMatrix = matrix

        drawingTexture?.clearDrawingTextures()
    }

    private func prepareNext() {
        gestureManager.reset()

        fingerGesture?.clear()
        pencilGesture?.clear()

        drawingTexture?.clearDrawingTextures()
    }
}

extension Canvas: FingerGestureSender {
    func drawOnCanvas(_ gesture: FingerGesture, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard gestureManager.update(gesture) is FingerGesture,
              let drawingTexture else { return }

        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()

        runDisplayLinkLoop(touchState != .ended)
    }
    func transformCanvas(_ gesture: FingerGesture, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState) {
        guard gestureManager.update(gesture) is FingerGesture,
              let newMatrix = transforming.update(transformationData: TransformationData.init(touchPoints: touchPointArrayDictionary),
                                                  centerPoint: Calc.getCenter(frame.size),
                                                  touchState: touchState) else { return }
        matrix = newMatrix

        runDisplayLinkLoop(touchState != .ended)
    }
    func touchEnded(_ gesture: FingerGesture) {
        guard gestureManager.update(gesture) is FingerGesture else { return }
        prepareNext()
    }
    func cancel(_ gesture: FingerGesture) {
        guard gestureManager.update(gesture) is FingerGesture else { return }
        prepareNext()
    }
}

extension Canvas: PencilGestureSender {
    func drawOnCanvas(_ gesture: PencilGesture, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard let drawingTexture else { return }

        if gestureManager.currentGesture is FingerGesture {
            cancelFingerDrawing()
        }
        gestureManager.update(gesture)

        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()

        runDisplayLinkLoop(touchState != .ended)
    }
    func touchEnded(_ gesture: PencilGesture) {
        prepareNext()
    }
    func cancel(_ gesture: PencilGesture) {
        prepareNext()
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
