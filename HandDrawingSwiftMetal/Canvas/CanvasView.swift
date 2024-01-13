//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import Combine

/// A user can use drawing tools to draw lines on the texture and then transform it.
class CanvasView: MTKTextureDisplayView {

    var drawingTool: DrawingToolType {
        get { viewModel!.drawingTool }
        set { viewModel!.drawingTool = newValue }
    }

    var brushDiameter: Int {
        get { viewModel!.brushDiameter }
        set { viewModel?.brushDiameter = newValue }
    }
    var eraserDiameter: Int {
        get { viewModel!.eraserDiameter }
        set { viewModel?.eraserDiameter = newValue }
    }

    var brushColor: UIColor {
        get { viewModel!.brushColor }
        set { viewModel?.brushColor = newValue }
    }
    var eraserAlpha: Int {
        get { viewModel!.eraserAlpha }
        set { viewModel?.eraserAlpha = newValue }
    }

    private (set) var viewModel: CanvasViewModel?

    @Published private (set) var undoCount: Int = 0

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

        assert(viewModel != nil, "viewModel is nil.")
        viewModel?.frameSize = frame.size
    }

    private func commonInitialization() {
        _ = Pipeline.shared

        inputManager = InputManager()
        fingerInput = FingerGestureWithStorage(view: self, delegate: self)
        pencilInput = PencilGestureWithStorage(view: self, delegate: self)

        undoManager.levelsOfUndo = 8

        undoManager.$undoCount
            .sink { [weak self] newValue in
                self?.undoCount = newValue
            }
            .store(in: &cancellables)

        $textureSize
            .sink { [weak self] newSize in
                guard let self else { return }
                viewModel?.initAllTextures(newSize)
                refreshCanvas()
            }
            .store(in: &cancellables)
    }

    func setViewModel(_ viewModel: CanvasViewModel) {
        self.viewModel = viewModel

        self.viewModel?.layerManager.$setNeedsDisplay
            .sink { [weak self] result in
                guard result, let self else { return }
                refreshCanvas()
        }
        .store(in: &cancellables)

        self.viewModel?.layerManager.$addUndoObject
            .sink { [weak self] _ in
                self?.registerDrawingUndoAction()
        }
        .store(in: &cancellables)
    }

    func newCanvas() {
        viewModel?.projectName = Calendar.currentDate

        clearUndo()

        resetMatrix()

        viewModel?.layerManager.initLayerManager(textureSize)
        viewModel?.layerManager.updateNonSelectedTextures()
        refreshCanvas()
    }
    func refreshCanvas() {
        viewModel?.mergeAllLayers(backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                  to: rootTexture,
                                  commandBuffer)
        setNeedsDisplay()
    }

    /// Reset the canvas transformation matrix to identity.
    func resetMatrix() {
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

extension CanvasView: FingerGestureWithStorageSender {
    func drawOnTexture(_ input: FingerGestureWithStorage, 
                       iterator: Iterator<TouchPoint>,
                       touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage,
              let viewModel
        else { return }

        if touchState == .ended {
            registerDrawingUndoAction()
        }
        viewModel.drawOnDrawingTexture(with: iterator,
                                       matrix: matrix,
                                       touchState: touchState,
                                       commandBuffer)
        viewModel.mergeAllLayers(backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                 to: rootTexture,
                                 commandBuffer)
        runDisplayLinkLoop(touchState != .ended)
    }
    func transformTexture(_ input: FingerGestureWithStorage, 
                          touchPointArrayDictionary: [Int: [TouchPoint]],
                          touchState: TouchState) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage
        else { return }

        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        if let newMatrix = viewModel?.getMatrix(transformationData: transformationData,
                                                frameCenterPoint: Calc.getCenter(frame.size),
                                                touchState: touchState) {
            matrix = newMatrix
        }
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
    func drawOnTexture(_ input: PencilGestureWithStorage, 
                       iterator: Iterator<TouchPoint>,
                       touchState: TouchState) {
        guard let viewModel
        else { return }

        if inputManager.currentInput is FingerGestureWithStorage {
            cancelFingerDrawing()
        }
        inputManager.updateInput(input)

        if touchState == .ended {
            registerDrawingUndoAction()
        }

        viewModel.drawOnDrawingTexture(with: iterator,
                                       matrix: matrix,
                                       touchState: touchState,
                                       commandBuffer)
        viewModel.mergeAllLayers(backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                                 to: rootTexture,
                                 commandBuffer)
        runDisplayLinkLoop(touchState != .ended)
    }
    func touchEnded(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
    func cancel(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
}
