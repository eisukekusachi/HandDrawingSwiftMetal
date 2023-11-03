//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

/// A user can use drawing tools to draw lines on the texture and then transform it.
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
    private var fingerInput: FingerDrawingInput!
    private var pencilInput: PencilDrawingInput!

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

        displayViewDelegate = self

        inputManager = InputManager()
        fingerInput = FingerDrawingInput(view: self, delegate: self)
        pencilInput = PencilDrawingInput(view: self, delegate: self)

        brushDrawingTexture = BrushDrawingTexture(canvas: self)
        eraserDrawingTexture = EraserDrawingTexture(canvas: self)
        
        transforming = Transforming()
        layers = LayerManager(canvas: self)
    }

    func refreshDisplayTexture() {
        guard let drawingTexture = currentDrawingTexture else { return }
        layers.mergeAllTextures(currentTextures: drawingTexture.currentDrawingTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: rootTexture)
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

extension Canvas: MTKTextureDisplayViewDelegate {
    func didChangeTextureSize(_ textureSize: CGSize) {
        brushDrawingTexture.initializeTextures(textureSize: textureSize)
        eraserDrawingTexture.initializeTextures(textureSize: textureSize)
        layers.initializeTextures(textureSize: textureSize)

        refreshDisplayTexture()
    }
}

extension Canvas: FingerDrawingInputSender {
    func drawOnTexture(_ input: FingerDrawingInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerDrawingInput,
              let drawingTexture = currentDrawingTexture
        else { return }
        
        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func transformTexture(_ input: FingerDrawingInput, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState) {
        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        guard inputManager.updateInput(input) is FingerDrawingInput,
              let newMatrix = transforming.update(transformationData: transformationData,
                                                  centerPoint: Calc.getCenter(frame.size),
                                                  touchState: touchState)
        else { return }
        
        matrix = newMatrix
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: FingerDrawingInput) {
        guard inputManager.updateInput(input) is FingerDrawingInput else { return }
        prepareForNextDrawing()
    }

    func cancel(_ input: FingerDrawingInput) {
        guard inputManager.updateInput(input) is FingerDrawingInput else { return }
        prepareForNextDrawing()
    }
}

extension Canvas: PencilDrawingInputSender {
    func drawOnTexture(_ input: PencilDrawingInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard let drawingTexture = currentDrawingTexture else { return }

        if inputManager.currentInput is FingerDrawingInput {
            cancelFingerDrawing()
        }

        inputManager.updateInput(input)

        drawingTexture.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshDisplayTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: PencilDrawingInput) {
        prepareForNextDrawing()
    }

    func cancel(_ input: PencilDrawingInput) {
        prepareForNextDrawing()
    }
}
