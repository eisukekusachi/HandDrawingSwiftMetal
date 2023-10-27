//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class Canvas: MTKTextureDisplayView {

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
    private var inputManager: InputManager!
    private var fingerInput: FingerInput!
    private var pencilInput: PencilInput!

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

        inputManager = InputManager()
        fingerInput = FingerInput(view: self, delegate: self)
        pencilInput = PencilInput(view: self, delegate: self)

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
        fingerInput.clear()
        transforming.storedMatrix = matrix
        currentDrawingTexture?.clearDrawingTextures()
    }

    private func prepareForNextDrawing() {
        inputManager.clear()
        fingerInput?.clear()
        pencilInput?.clear()
        currentDrawingTexture?.clearDrawingTextures()
    }
}

extension Canvas: FingerGestureSender {
    func drawOnTexture(_ input: FingerInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerInput,
              let drawingTexture = currentDrawingTexture
        else { return }
        
        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func transformTexture(_ input: FingerInput, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState) {
        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        guard inputManager.updateInput(input) is FingerInput,
              let newMatrix = transforming.update(transformationData: transformationData,
                                                  centerPoint: Calc.getCenter(frame.size),
                                                  touchState: touchState)
        else { return }
        
        matrix = newMatrix
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: FingerInput) {
        guard inputManager.updateInput(input) is FingerInput else { return }
        prepareForNextDrawing()
    }

    func cancel(_ input: FingerInput) {
        guard inputManager.updateInput(input) is FingerInput else { return }
        prepareForNextDrawing()
    }
}

extension Canvas: PencilInputSender {
    func drawOnTexture(_ input: PencilInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard let drawingTexture = currentDrawingTexture else { return }

        if inputManager.currentInput is FingerInput {
            cancelFingerDrawing()
        }

        inputManager.updateInput(input)

        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: PencilInput) {
        prepareForNextDrawing()
    }

    func cancel(_ input: PencilInput) {
        prepareForNextDrawing()
    }
}
