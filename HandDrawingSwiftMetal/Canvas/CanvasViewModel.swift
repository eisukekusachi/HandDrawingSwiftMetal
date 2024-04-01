//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

class CanvasViewModel {

    let drawingTool = DrawingToolModel()

    var frameSize: CGSize = .zero {
        didSet {
            drawingTool.frameSize = frameSize
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var undoObject: UndoObject {
        return UndoObject(index: drawingTool.layerManager.index,
                          layers: drawingTool.layerManager.layers)
    }

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    var clearUndoPublisher: AnyPublisher<Void, Never> {
        clearUndoSubject.eraseToAnyPublisher()
    }

    private let touchManager = TouchManager()

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    /// A protocol for managing transformations
    private let transforming = Transforming()

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!


    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let clearUndoSubject = PassthroughSubject<Void, Never>()

    private var displayLink: CADisplayLink?

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        drawingTool.layerManager.addUndoObjectToUndoStackPublisher
            .subscribe(addUndoObjectToUndoStackSubject)
            .store(in: &cancellables)

        drawingTool.pauseDisplayLinkSubject
            .sink { [weak self] pause in
                self?.pauseDisplayLinkLoop(pause)
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)

        // Configure the display link for rendering.
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

}

extension CanvasViewModel {

    func handleFingerInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                print("touchPointArray is empty.")
            }
        }
        touchManager.appendFingerTouches(event, in: view)
    }
    func handlePencilInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                print("touchPointArray is empty.")
            }
        }
        touchManager.appendPencilTouches(event, in: view)
    }

}
extension CanvasViewModel {

    func didTapResetTransformButton() {
        resetMatrix()
        drawingTool.commitCommandsInCommandBuffer.send()
    }

    func didTapNewCanvasButton() {

        clearUndoSubject.send()

        projectName = Calendar.currentDate

        resetMatrix()

        drawingTool.initLayers(textureSize: drawingTool.textureSizeSubject.value)

        drawingTool.commitCommandToMergeAllLayersToRootTextureSubject.send()
    }

}

extension CanvasViewModel {

    func initTextureSizeIfSizeIsZero(frameSize: CGSize, drawableSize: CGSize) {
        if drawingTool.textureSizeSubject.value == .zero &&
           frameSize.isSameRatio(drawableSize) {
            drawingTool.textureSizeSubject.send(drawableSize)
        }
    }

    func resetMatrix() {
        transforming.setStoredMatrix(.identity)
        drawingTool.matrixSubject.send(.identity)
    }

    func getMatrix(transformationData: TransformationData, touchPhase: UITouch.Phase) -> CGAffineTransform? {
        transforming.getMatrix(transformationData: transformationData,
                               frameCenterPoint: Calc.getCenter(frameSize),
                               touchPhase: touchPhase)
    }

    func setMatrix(_ matrix: CGAffineTransform) {
        transforming.setStoredMatrix(matrix)
    }

}

extension CanvasViewModel {

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        drawingTool.commitCommandsInCommandBuffer.send()
    }

    /// Start or stop the display link loop based on the 'play' parameter.
    private func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if displayLink?.isPaused == false {
                // Pause the display link after updating the display.
                drawingTool.commitCommandsInCommandBuffer.send()
                displayLink?.isPaused = true
            }

        } else {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
        }
    }

}
