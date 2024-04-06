//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

protocol CanvasViewModelDelegate {
    func drawSegmentOnTexture(segment: LineSegment)
}

class CanvasViewModel {

    var delegate: CanvasViewModelDelegate?

    let lineDrawing = LineDrawing()
    let smoothLineDrawing = SmoothLineDrawing()

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

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

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
            if let lineSegment: LineSegment = makeLineSegment(touchManager, with: smoothLineDrawing) {
                delegate?.drawSegmentOnTexture(segment: lineSegment)
            }

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
        drawingTool.setNeedsDisplay()
    }

    func didTapNewCanvasButton() {

        clearUndoSubject.send()

        projectName = Calendar.currentDate

        resetMatrix()

        drawingTool.initLayers(textureSize: drawingTool.textureSizeSubject.value)

        drawingTool.mergeAllLayersToRootTexture()
        drawingTool.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    func makeLineSegment(
        _ touchManager: TouchManager,
        with drawing: DrawingLineProtocol
    ) -> LineSegment? {

        drawing.setHashValueIfNil(touchManager)

        guard
            let hashValue = drawing.hashValue,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue),
            let touchPoints = touchManager.getTouchPoints(with: hashValue)
        else { return nil }

        defer {
            if touchPhase == .ended {
                drawing.clear()
            }
        }

        let diffCount = touchPoints.count - drawing.iterator.array.count
        guard diffCount > 0 else { return nil }

        let newTouchPoints = touchPoints.suffix(diffCount)

        let dotPoints = newTouchPoints.map {
            DotPoint(
                touchPoint: $0,
                matrix: .identity,
                frameSize: frameSize,
                textureSize: drawingTool.textureSize
            )
        }
        drawing.appendToIterator(dotPoints)

        if touchPhase == .ended, let drawing = drawing as? SmoothLineDrawing {
            drawing.appendLastTouchToSmoothCurveIterator()
        }

        let curvePoints = Curve.makePoints(
            from: drawing.iterator,
            isFinishDrawing: touchPhase == .ended
        )

        return .init(
            dotPoints: curvePoints,
            parameters: .init(drawingTool),
            touchPhase: touchPhase
        )
    }

    func drawSegmentOnTexture(
        _ lineSegment: LineSegment,
        _ rootTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer?
    ) {
        guard let rootTexture,
              let commandBuffer,
              let drawingLayer = drawingTool.layerManager.drawingLayer
        else { return }

        drawingLayer.drawOnDrawingTexture(
            segment: lineSegment,
            on: drawingTool.layerManager.selectedTexture,
            commandBuffer)

        drawingTool.layerManager.addMergeAllLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: rootTexture,
            to: commandBuffer)

        pauseDisplayLinkSubject.send(lineSegment.touchPhase == .ended)
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
