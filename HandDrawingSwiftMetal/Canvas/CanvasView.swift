//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

/// A user can use drawing tools to draw lines on the texture and then transform it.
class CanvasView: MTKTextureDisplayView {

    private (set) var viewModel: CanvasViewModel?

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

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInitialization()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInitialization()
    }

    private func commonInitialization() {
        
        inputManager = InputManager()
        fingerInput = FingerGestureWithStorage(view: self, delegate: self)
        pencilInput = PencilGestureWithStorage(view: self, delegate: self)

        undoManager.levelsOfUndo = 8
    }

    func setViewModel(_ viewModel: CanvasViewModel) {
        self.viewModel = viewModel
    }

    private func cancelFingerDrawing() {
        fingerInput.clear()
        viewModel?.setMatrix(matrix)

        let commandBuffer = device!.makeCommandQueue()!.makeCommandBuffer()!
        viewModel?.parameters.layerManager.drawingLayer?.clearDrawingTextures(commandBuffer)
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
                       touchPhase: UITouch.Phase) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage,
              let viewModel
        else { return }

        if touchPhase == .ended {
            registerDrawingUndoAction()
        }

        viewModel.drawOnDrawingTexture(with: iterator,
                                       matrix: matrix,
                                       touchPhase: touchPhase,
                                       commandBuffer)

        viewModel.parameters.addCommandToMergeAllLayers(
            onto: rootTexture,
            to: commandBuffer
        )

        viewModel.parameters.pauseDisplayLinkSubject.send(touchPhase == .ended)
    }
    func transformTexture(_ input: FingerGestureWithStorage, 
                          touchPointArrayDictionary: [Int: [TouchPoint]],
                          touchPhase: UITouch.Phase) {
        guard inputManager.updateInput(input) is FingerGestureWithStorage,
              let viewModel
        else { return }

        let transformationData = TransformationData(touchPointArrayDictionary: touchPointArrayDictionary)
        if let newMatrix = viewModel.getMatrix(transformationData: transformationData,
                                               touchPhase: touchPhase) {
            matrix = newMatrix
        }

        viewModel.parameters.pauseDisplayLinkSubject.send(touchPhase == .ended)
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
                       touchPhase: UITouch.Phase) {
        guard let viewModel
        else { return }

        if inputManager.currentInput is FingerGestureWithStorage {
            cancelFingerDrawing()
        }
        inputManager.updateInput(input)

        if touchPhase == .ended {
            registerDrawingUndoAction()
        }

        viewModel.drawOnDrawingTexture(with: iterator,
                                       matrix: matrix,
                                       touchPhase: touchPhase,
                                       commandBuffer)

        viewModel.parameters.addCommandToMergeAllLayers(
            onto: rootTexture,
            to: commandBuffer
        )

        viewModel.parameters.pauseDisplayLinkSubject.send(touchPhase == .ended)
    }
    func touchEnded(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
    func cancel(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
}
