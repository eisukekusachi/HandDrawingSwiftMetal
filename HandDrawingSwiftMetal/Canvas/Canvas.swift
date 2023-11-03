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
            if currentDrawing is EraserDrawing {
                return .eraser
            } else {
                return .brush
            }
        }
        set {
            if newValue == .eraser {
                currentDrawing = eraserDrawing
            } else {
                currentDrawing = brushDrawing
            }
        }
    }

    var currentTexture: MTLTexture {
        return layers.currentTexture
    }

    var brushDiameter: Int {
        get { brushDrawing.brush.diameter }
        set { brushDrawing.brush.diameter = newValue }
    }

    var eraserDiameter: Int {
        get { eraserDrawing.eraser.diameter }
        set { eraserDrawing.eraser.diameter = newValue }
    }

    var brushColor: UIColor {
        get { brushDrawing.brush.color }
        set { brushDrawing.brush.setValue(color: newValue) }
    }

    var eraserAlpha: Int {
        get { eraserDrawing.eraser.alpha }
        set { eraserDrawing.eraser.setValue(alpha: newValue)}
    }

    private var currentDrawing: DrawingProtocol?
    private var brushDrawing: BrushDrawing!
    private var eraserDrawing: EraserDrawing!

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

        brushDrawing = BrushDrawing(canvas: self)
        eraserDrawing = EraserDrawing(canvas: self)
        
        transforming = Transforming()
        layers = LayerManager(canvas: self)
    }

    func refreshRootTexture() {
        guard let currentDrawing else { return }
        layers.mergeAllTextures(currentTextures: currentDrawing.currentDrawingTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: rootTexture)
    }

    func clearCanvas() {
        layers.clearTexture()
        refreshRootTexture()
    }

    /// Reset the canvas transformation matrix to identity.
    func resetCanvasMatrix() {
        matrix = CGAffineTransform.identity
        transforming.storedMatrix = matrix
    }

    private func cancelFingerDrawing() {
        fingerInput.clear()
        transforming.storedMatrix = matrix
        currentDrawing?.clearDrawingTextures()
    }

    private func prepareForNextDrawing() {
        inputManager.clear()
        fingerInput?.clear()
        pencilInput?.clear()
        currentDrawing?.clearDrawingTextures()
    }
}

extension Canvas: MTKTextureDisplayViewDelegate {
    func didChangeTextureSize(_ textureSize: CGSize) {
        brushDrawing.initializeTextures(textureSize)
        eraserDrawing.initializeTextures(textureSize)
        layers.initializeTextures(textureSize)

        refreshRootTexture()
    }
}

extension Canvas: FingerDrawingInputSender {
    func drawOnTexture(_ input: FingerDrawingInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerDrawingInput,
              let currentDrawing
        else { return }
        
        currentDrawing.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshRootTexture()
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
        guard let currentDrawing else { return }

        if inputManager.currentInput is FingerDrawingInput {
            cancelFingerDrawing()
        }

        inputManager.updateInput(input)

        currentDrawing.drawOnDrawingTexture(with: iterator, touchState: touchState)
        refreshRootTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: PencilDrawingInput) {
        prepareForNextDrawing()
    }

    func cancel(_ input: PencilDrawingInput) {
        prepareForNextDrawing()
    }
}
