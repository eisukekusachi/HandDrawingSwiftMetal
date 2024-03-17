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
    }

    func refreshTextures() {
        guard let commandBuffer = device!.makeCommandQueue()?.makeCommandBuffer(),
              let textureSize = viewModel?.parameters.textureSizeSubject.value else { return }

        viewModel?.parameters.layerManager.initLayerManager(textureSize)

        viewModel?.mergeAllLayers(to: rootTexture, commandBuffer)
        commandBuffer.commit()

        viewModel?.parameters.setNeedsDisplaySubject.send()
    }

    func setViewModel(_ viewModel: CanvasViewModel) {
        self.viewModel = viewModel

        self.viewModel?.parameters.layerManager.$setNeedsDisplay
            .sink { [weak self] result in
                guard result, let self else { return }

                viewModel.mergeAllLayers(to: rootTexture,
                                         commandBuffer)
                viewModel.parameters.setNeedsDisplaySubject.send()
        }
        .store(in: &cancellables)

        self.viewModel?.parameters.layerManager.$addUndoObject
            .sink { [weak self] _ in
                self?.registerDrawingUndoAction()
        }
        .store(in: &cancellables)
    }

    func newCanvas() {
        guard let textureSize = viewModel?.parameters.textureSizeSubject.value else { return }

        viewModel?.projectName = Calendar.currentDate

        clearUndo()

        viewModel?.resetMatrix()

        viewModel?.parameters.layerManager.initLayerManager(textureSize)
        viewModel?.parameters.layerManager.updateNonSelectedTextures()
        viewModel?.mergeAllLayers(to: rootTexture,
                                  commandBuffer)
        viewModel?.parameters.setNeedsDisplaySubject.send(())
    }

    private func cancelFingerDrawing() {
        fingerInput.clear()
        viewModel?.setMatrix(matrix)

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
        viewModel.mergeAllLayers(to: rootTexture,
                                 commandBuffer)

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
        viewModel.mergeAllLayers(to: rootTexture,
                                 commandBuffer)

        viewModel.parameters.pauseDisplayLinkSubject.send(touchPhase == .ended)
    }
    func touchEnded(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
    func cancel(_ input: PencilGestureWithStorage) {
        prepareForNextDrawing()
    }
}
