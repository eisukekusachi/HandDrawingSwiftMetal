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

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

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
    private let actionManager = ActionManager()

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    /// A protocol for managing transformations
    private let transforming = Transforming()

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(false)

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let clearUndoSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        drawingTool.layerManager.addUndoObjectToUndoStackPublisher
            .subscribe(addUndoObjectToUndoStackSubject)
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

}

extension CanvasViewModel {

    func handleFingerInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                actionManager.reset()
            }
        }
        touchManager.appendFingerTouches(event, in: view)

        let newState: ActionState = .init(from: touchManager.touchPointsDictionary)

        switch actionManager.updateState(newState) {
        case .drawing:
            print("drawing")

        case .transforming:
            print("transforming")

        default:
            break
        }
    }

    func handlePencilInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                actionManager.reset()
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
