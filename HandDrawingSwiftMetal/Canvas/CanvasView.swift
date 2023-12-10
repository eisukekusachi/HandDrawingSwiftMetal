//
//  CanvasView.swift
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
class CanvasView: MTKTextureDisplayView {
    var viewModel: CanvasViewModel?

    weak var canvasDelegate: CanvasDelegate?

    /// The currently selected drawing tool, either brush or eraser.
    @Published var drawingTool: DrawingToolType = .brush

    var brushDiameter: Int {
        get { (viewModel?.drawingBrush.tool as? DrawingToolBrush)!.diameter }
        set { (viewModel?.drawingBrush.tool as? DrawingToolBrush)?.diameter = newValue }
    }
    var eraserDiameter: Int {
        get { (viewModel?.drawingEraser.tool as? DrawingToolEraser)!.diameter }
        set { (viewModel?.drawingEraser.tool as? DrawingToolEraser)?.diameter = newValue }
    }

    var brushColor: UIColor {
        get { (viewModel?.drawingBrush.tool as? DrawingToolBrush)!.color }
        set { (viewModel?.drawingBrush.tool as? DrawingToolBrush)?.setValue(color: newValue) }
    }
    var eraserAlpha: Int {
        get { (viewModel?.drawingEraser.tool as? DrawingToolEraser)!.alpha }
        set { (viewModel?.drawingEraser.tool as? DrawingToolEraser)?.setValue(alpha: newValue)}
    }

    /// Override UndoManager with ``UndoManagerWithCount``
    override var undoManager: UndoManagerWithCount {
        return undoManagerWithCount
    }

    /// An undoManager with undoCount and redoCount
    private let undoManagerWithCount = UndoManagerWithCount()


    /// A manager for handling finger and pencil inputs.
    private var inputManager: InputManager!
    private var fingerInput: FingerGestureWithStorage!
    private var pencilInput: PencilGestureWithStorage!

    private var cancellables = Set<AnyCancellable>()

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInitialization()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInitialization()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        viewModel?.setFrameSize(frame.size)
    }

    private func commonInitialization() {
        _ = Pipeline.shared

        $drawingTool
            .sink { [weak self] newValue in
                self?.viewModel?.setCurrentDrawing(newValue)
            }
            .store(in: &cancellables)

        displayViewDelegate = self

        inputManager = InputManager()
        fingerInput = FingerGestureWithStorage(view: self, delegate: self)
        pencilInput = PencilGestureWithStorage(view: self, delegate: self)

        drawingTool = .brush

        undoManager.levelsOfUndo = 8
    }

    func refreshRootTexture() {
        guard let viewModel,
              let drawing = viewModel.drawing
        else { return }

        viewModel.layerManager.merge(textures: drawing.getDrawingTextures(viewModel.currentTexture),
                                     backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                     into: rootTexture,
                                     commandBuffer)
    }
    func newCanvas() {
        viewModel?.projectName = Calendar.currentDate

        clearUndo()

        resetCanvasMatrix()

        viewModel?.clearCurrentTexture(commandBuffer)
        refreshRootTexture()

        setNeedsDisplay()
    }
    func clearCanvas() {
        guard let viewModel else { return }

        registerDrawingUndoAction(viewModel.currentTexture)

        viewModel.clearCurrentTexture(commandBuffer)
        refreshRootTexture()

        setNeedsDisplay()
    }

    /// Reset the canvas transformation matrix to identity.
    func resetCanvasMatrix() {
        matrix = CGAffineTransform.identity
        viewModel?.setStoredMatrix(matrix)
    }

    private func cancelFingerDrawing() {
        fingerInput.clear()
        viewModel?.setStoredMatrix(matrix)

        let commandBuffer = device!.makeCommandQueue()!.makeCommandBuffer()!
        viewModel?.drawing?.clearDrawingTextures(commandBuffer)
        commandBuffer.commit()
    }

    private func prepareForNextDrawing() {
        inputManager.clear()
        fingerInput?.clear()
        pencilInput?.clear()
    }
}

extension CanvasView: MTKTextureDisplayViewDelegate {
    func didChangeTextureSize(_ textureSize: CGSize) {
        viewModel?.initTextures(textureSize)

        refreshRootTexture()
    }
}

extension CanvasView: FingerGestureWithStorageSender {
    func drawOnTexture(_ input: FingerGestureWithStorage, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage,
              let viewModel,
              let drawing = viewModel.drawing
        else { return }

        if touchState == .ended {
            registerDrawingUndoAction(viewModel.currentTexture)
        }

        drawing.drawOnDrawingTexture(with: iterator,
                                     matrix: matrix,
                                     on: viewModel.currentTexture,
                                     touchState,
                                     commandBuffer)
        refreshRootTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func transformTexture(_ input: FingerGestureWithStorage, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState) {
        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        guard inputManager.updateInput(input) is FingerGestureWithStorage,
              let newMatrix = viewModel?.getMatrix(transformationData: transformationData,
                                                   frameCenterPoint: Calc.getCenter(frame.size),
                                                   touchState: touchState)
        else { return }

        matrix = newMatrix
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: FingerGestureWithStorage) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage else { return }
        prepareForNextDrawing()
    }

    func cancel(_ input: FingerGestureWithStorage) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage else { return }
        prepareForNextDrawing()
    }
}

extension CanvasView: PencilGestureWithStorageSender {
    func drawOnTexture(_ input: PencilGestureWithStorage, iterator: Iterator<TouchPoint>, touchState: TouchState) {
        guard let viewModel,
              let drawing = viewModel.drawing
        else { return }

        if inputManager.currentInput is FingerGestureWithStorage {
            cancelFingerDrawing()
        }

        inputManager.updateInput(input)

        if touchState == .ended {
            registerDrawingUndoAction(viewModel.currentTexture)
        }

        drawing.drawOnDrawingTexture(with: iterator,
                                     matrix: matrix,
                                     on: viewModel.currentTexture,
                                     touchState,
                                     commandBuffer)
        refreshRootTexture()
        runDisplayLinkLoop(touchState != .ended)
    }

    func touchEnded(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }

    func cancel(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
}
