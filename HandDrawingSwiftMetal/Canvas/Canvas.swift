//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class Canvas: TextureDisplayView {

    /// The currently selected drawing tool, either brush or eraser.
    var drawingTool: DrawingTool {
        get {
            if currentDrawingTexture is EraserDrawingTexture {
                return .eraser
            } else {
                return .brush
            }
        }
        set {
            if newValue == .eraser {
                currentDrawingTexture = eraserDrawingTexture
            } else {
                currentDrawingTexture = brushDrawingTexture
            }
        }
    }

    var currentTexture: MTLTexture {
        return layers.currentTexture
    }

    var brushDiameter: Int {
        get { brushDrawingTexture.brush.diameter }
        set { brushDrawingTexture.brush.diameter = newValue }
    }

    var eraserDiameter: Int {
        get { eraserDrawingTexture.eraser.diameter }
        set { eraserDrawingTexture.eraser.diameter = newValue }
    }

    var brushColor: UIColor {
        get { brushDrawingTexture.brush.color }
        set { brushDrawingTexture.brush.setValue(color: newValue) }
    }

    var eraserAlpha: Int {
        get { eraserDrawingTexture.eraser.alpha }
        set { eraserDrawingTexture.eraser.setValue(alpha: newValue)}
    }

    private var currentDrawingTexture: DrawingTextureProtocol?
    private var brushDrawingTexture: BrushDrawingTexture!
    private var eraserDrawingTexture: EraserDrawingTexture!

    private var transforming: TransformingProtocol!
    private var layers: LayerManagerProtocol!

    /// A manager for handling finger and pencil input gestures.
    private var gestureManager: GestureManager!
    private var fingerGesture: FingerGesture!
    private var pencilGesture: PencilGesture!

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInitialization()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInitialization()
    }

    private func commonInitialization() {
        _ = Pipeline.shared

        gestureManager = GestureManager()
        fingerGesture = FingerGesture(view: self, delegate: self)
        pencilGesture = PencilGesture(view: self, delegate: self)
        
        brushDrawingTexture = BrushDrawingTexture(canvas: self)
        eraserDrawingTexture = EraserDrawingTexture(canvas: self)
        
        transforming = Transforming()
        layers = LayerManager(canvas: self)
    }

    override func layoutSubviews() {
        if let drawableSize = currentDrawable?.texture.size, displayTexture == nil {
            initializeTextures(textureSize: drawableSize)
            refreshDisplayTexture()
            setNeedsDisplay()
        }
    }

    override func initializeTextures(textureSize: CGSize) {
        super.initializeTextures(textureSize: textureSize)
        brushDrawingTexture.initializeTextures(textureSize: textureSize)
        eraserDrawingTexture.initializeTextures(textureSize: textureSize)
        layers.initializeTextures(textureSize: textureSize)
    }

    func refreshDisplayTexture() {
        guard let drawingTexture = currentDrawingTexture else { return }
        layers.mergeAllTextures(currentTextures: drawingTexture.currentTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: displayTexture)
    }

    func clearCanvas() {
        layers.clearTexture()
        refreshDisplayTexture()
    }

    /// Reset the canvas transformation matrix to identity.
    func resetCanvasMatrix() {
        matrix = CGAffineTransform.identity
        transforming.storedMatrix = matrix
    }

    private func cancelFingerDrawing() {
        fingerGesture.clear()
        transforming.storedMatrix = matrix
        currentDrawingTexture?.clearDrawingTextures()
    }

    private func prepareForNextDrawing() {
        gestureManager.clear()
        fingerGesture?.clear()
        pencilGesture?.clear()
        currentDrawingTexture?.clearDrawingTextures()
    }
}

extension Canvas: FingerGestureSender {
    func drawOnCanvas(_ gesture: FingerGesture, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard gestureManager.update(gesture) is FingerGesture,
              let drawingTexture = currentDrawingTexture
        else { return }
        
        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func transformCanvas(_ gesture: FingerGesture, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState) {
        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        guard gestureManager.update(gesture) is FingerGesture,
              let newMatrix = transforming.update(transformationData: transformationData,
                                                  centerPoint: Calc.getCenter(frame.size),
                                                  touchState: touchState)
        else { return }
        
        matrix = newMatrix
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ gesture: FingerGesture) {
        guard gestureManager.update(gesture) is FingerGesture else { return }
        prepareForNextDrawing()
    }

    func cancel(_ gesture: FingerGesture) {
        guard gestureManager.update(gesture) is FingerGesture else { return }
        prepareForNextDrawing()
    }
}

extension Canvas: PencilGestureSender {
    func drawOnCanvas(_ gesture: PencilGesture, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard let drawingTexture = currentDrawingTexture else { return }

        if gestureManager.currentGesture is FingerGesture {
            cancelFingerDrawing()
        }

        gestureManager.update(gesture)

        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ gesture: PencilGesture) {
        prepareForNextDrawing()
    }

    func cancel(_ gesture: PencilGesture) {
        prepareForNextDrawing()
    }
}
