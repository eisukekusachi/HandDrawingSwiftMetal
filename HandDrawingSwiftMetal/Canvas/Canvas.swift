//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import Combine

protocol CanvasDelegate: AnyObject {
    func didUndoRedo()
}

/// A user can use drawing tools to draw lines on the texture and then transform it.
class Canvas: MTKTextureDisplayView {

    weak var canvasDelegate: CanvasDelegate?

    var projectName: String = Calendar.currentDate

    /// The currently selected drawing tool, either brush or eraser.
    @Published var drawingTool: DrawingToolType = .brush

    var brushDiameter: Int {
        get { (drawingBrush.drawingTool as? DrawingToolBrush)!.diameter }
        set { (drawingBrush.drawingTool as? DrawingToolBrush)?.diameter = newValue }
    }
    var eraserDiameter: Int {
        get { (drawingEraser.drawingTool as? DrawingToolEraser)!.diameter }
        set { (drawingEraser.drawingTool as? DrawingToolEraser)?.diameter = newValue }
    }

    var brushColor: UIColor {
        get { (drawingBrush.drawingTool as? DrawingToolBrush)!.color }
        set { (drawingBrush.drawingTool as? DrawingToolBrush)?.setValue(color: newValue) }
    }
    var eraserAlpha: Int {
        get { (drawingEraser.drawingTool as? DrawingToolEraser)!.alpha }
        set { (drawingEraser.drawingTool as? DrawingToolEraser)?.setValue(alpha: newValue)}
    }

    var currentTexture: MTLTexture {
        return layers.currentTexture
    }

    /// Manage texture layers
    private (set) var layers: LayerManagerProtocol!

    /// Manage drawing
    private var drawing: DrawingProtocol?

    /// Drawing with a brush
    private var drawingBrush: DrawingBrush!

    /// Drawing with an eraser
    private var drawingEraser: DrawingEraser!


    /// Manage transformations
    private var transforming: TransformingProtocol!


    /// An undoManager with undoCount and redoCount
    /// Override the existing UndoManager
    override var undoManager: UndoDrawing {
        return undoDrawing
    }
    private let undoDrawing = UndoDrawing()

    /// A manager for handling finger and pencil input gestures.
    private var inputManager: InputManager!
    private var fingerInput: FingerDrawingInput!
    private var pencilInput: PencilDrawingInput!

    private var cancellables = Set<AnyCancellable>()

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

        $drawingTool
            .sink { newValue in
                switch newValue {
                case .brush:
                    self.drawing = self.drawingBrush
                case .eraser:
                    self.drawing = self.drawingEraser
                }
            }
            .store(in: &cancellables)

        displayViewDelegate = self

        inputManager = InputManager()
        fingerInput = FingerDrawingInput(view: self, delegate: self)
        pencilInput = PencilDrawingInput(view: self, delegate: self)

        drawingBrush = DrawingBrush(canvas: self)
        drawingEraser = DrawingEraser(canvas: self)
        drawingTool = .brush

        transforming = Transforming()
        layers = LayerManager(canvas: self)

        undoDrawing.levelsOfUndo = 8
    }

    func refreshRootTexture() {
        guard let drawing else { return }
        layers.mergeAllTextures(currentTextures: drawing.currentDrawingTextures,
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
        drawing?.clearDrawingTextures()
    }

    private func prepareForNextDrawing() {
        inputManager.clear()
        fingerInput?.clear()
        pencilInput?.clear()
        drawing?.clearDrawingTextures()
    }
}

extension Canvas: MTKTextureDisplayViewDelegate {
    func didChangeTextureSize(_ textureSize: CGSize) {
        drawingBrush.initializeTextures(textureSize)
        drawingEraser.initializeTextures(textureSize)
        layers.initializeTextures(textureSize)

        refreshRootTexture()
    }
}

extension Canvas: FingerDrawingInputSender {
    func drawOnTexture(_ input: FingerDrawingInput, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerDrawingInput,
              let drawing
        else { return }

        if touchState == .ended {
            registerDrawingUndoAction(currentTexture)
        }

        drawing.drawOnDrawingTexture(with: iterator, touchState: touchState)
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
        guard let drawing else { return }

        if inputManager.currentInput is FingerDrawingInput {
            cancelFingerDrawing()
        }

        inputManager.updateInput(input)

        if touchState == .ended {
            registerDrawingUndoAction(currentTexture)
        }

        drawing.drawOnDrawingTexture(with: iterator, touchState: touchState)
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
