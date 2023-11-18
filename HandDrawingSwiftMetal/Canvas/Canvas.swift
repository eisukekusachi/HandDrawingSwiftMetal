//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

protocol CanvasDelegate: AnyObject {
    func didUndoRedo()
}

/// A user can use drawing tools to draw lines on the texture and then transform it.
class Canvas: MTKTextureDisplayView {

    weak var canvasDelegate: CanvasDelegate?

    var projectName: String = Calendar.currentDate

    /// The currently selected drawing tool, either brush or eraser.
    var drawingTool: DrawingToolType {
        get {
            if currentDrawing is DrawingEraser {
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

    override var undoManager: UndoDrawing {
        return undoDrawing
    }
    private let undoDrawing = UndoDrawing()

    private var currentDrawing: DrawingProtocol?
    private var brushDrawing: DrawingBrush!
    private var eraserDrawing: DrawingEraser!

    private var transforming: TransformingProtocol!
    private (set) var layers: LayerManagerProtocol!

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

        brushDrawing = DrawingBrush(canvas: self)
        eraserDrawing = DrawingEraser(canvas: self)
        
        transforming = Transforming()
        layers = LayerManager(canvas: self)

        undoDrawing.levelsOfUndo = 8
    }

    func refreshRootTexture() {
        guard let currentDrawing else { return }
        layers.mergeAllTextures(currentTextures: currentDrawing.currentDrawingTextures,
                                backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                to: rootTexture)
    }
    func newCanvas() {
        projectName = Calendar.currentDate

        clearUndo()

        resetCanvasMatrix()

        layers.clearTexture()
        refreshRootTexture()

        setNeedsDisplay()
    }
    func clearCanvas() {
        registerDrawingUndoAction(currentTexture)

        layers.clearTexture()
        refreshRootTexture()

        setNeedsDisplay()
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

        if touchState == .ended {
            registerDrawingUndoAction(currentTexture)
        }

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

        if touchState == .ended {
            registerDrawingUndoAction(currentTexture)
        }

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

// Undo / Redo
extension Canvas {
    var canUndo: Bool {
        undoDrawing.canUndo
    }
    var canRedo: Bool {
        undoDrawing.canRedo
    }

    func clearUndo() {
        undoDrawing.clear()
    }
    func undo() {
        undoDrawing.performUndo()
        canvasDelegate?.didUndoRedo()
    }
    func redo() {
        undoDrawing.performRedo()
        canvasDelegate?.didUndoRedo()
    }

    func registerDrawingUndoAction(_ currentTexture: MTLTexture) {
        registerDrawingUndoAction(with: UndoObject(texture: currentTexture))

        undoDrawing.incrementUndoCount()
        canvasDelegate?.didUndoRedo()

        if let newTexture = duplicateTexture(currentTexture) {
            layers.setTexture(newTexture)
        }
    }

    /// Registers an action to undo the drawing operation.
    func registerDrawingUndoAction(with undoObject: UndoObject) {
        undoDrawing.registerUndo(withTarget: self) { [unowned self] _ in

            registerDrawingUndoAction(with: .init(texture: currentTexture))

            canvasDelegate?.didUndoRedo()

            layers.setTexture(undoObject.texture)

            refreshRootTexture()
            setNeedsDisplay()
        }
    }
}
