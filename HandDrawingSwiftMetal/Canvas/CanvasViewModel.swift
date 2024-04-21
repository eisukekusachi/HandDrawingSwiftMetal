//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

protocol CanvasViewModelDelegate {

    var commandBuffer: MTLCommandBuffer { get }
    var rootTexture: MTLTexture { get }

    func initRootTexture(textureSize: CGSize)

    func clearCommandBuffer()

    func registerDrawingUndoAction(with undoObject: UndoObject)

    func refreshCanvasByCallingSetNeedsDisplay()

}

class CanvasViewModel {

    var delegate: CanvasViewModelDelegate?

    let drawing = Drawing()

    let transforming = Transforming()

    let layerManager = LayerManager()

    let drawingTool = DrawingToolModel()

    let undoHistoryManager = UndoHistoryManager()

    let inputManager = InputManager()

    var undoObject: UndoObject {
        return UndoObject(
            index: layerManager.index,
            layers: layerManager.layers
        )
    }

    var frameSize: CGSize = .zero {
        didSet {
            drawing.frameSize = frameSize

            layerManager.frameSize = frameSize

            transforming.screenCenter = .init(
                x: frameSize.width * 0.5,
                y: frameSize.height * 0.5
            )
        }
    }

    var textureSize: CGSize = .zero {
        didSet {
            guard textureSize != .zero else { return }

            delegate?.initRootTexture(textureSize: textureSize)

            layerManager.initLayers(with: textureSize)

            drawing.textureSize = textureSize

            refreshCanvasWithMergingAllLayers()
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    var clearUndoPublisher: AnyPublisher<Void, Never> {
        clearUndoSubject.eraseToAnyPublisher()
    }

    var requestShowingLayerViewPublisher: AnyPublisher<Void, Never> {
        requestShowingLayerViewSubject.eraseToAnyPublisher()
    }

    private let lineDrawing = LineDrawing()
    private let smoothLineDrawing = SmoothLineDrawing()

    private let touchManager = TouchManager()
    private let actionManager = ActionManager()

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let clearUndoSubject = PassthroughSubject<Void, Never>()

    private let requestShowingLayerViewSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        undoHistoryManager.addUndoObjectToUndoStackPublisher
            .sink { [weak self] in
                self?.registerDrawingUndoAction()
            }
            .store(in: &cancellables)

        layerManager.refreshCanvasWithMergingDrawingLayersPublisher
            .sink { [weak self] in
                self?.refreshCanvasWithMergingDrawingLayers()
            }
            .store(in: &cancellables)

        layerManager.refreshCanvasWithMergingAllLayersPublisher
            .sink { [weak self] in
                self?.refreshCanvasWithMergingAllLayers()
            }
            .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                self?.layerManager.setDrawingLayer(tool)
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

    func initTextureSizeIfSizeIsZero(frameSize: CGSize, drawableSize: CGSize) {
        if textureSize == .zero &&
           frameSize.isSameRatio(drawableSize) {
            textureSize = drawableSize
        }
    }

    func onLayerButtonTapped() {
        Task {
            try? await layerManager.updateCurrentThumbnail()

            DispatchQueue.main.async { [weak self] in
                self?.requestShowingLayerViewSubject.send()
            }
        }
    }

}

extension CanvasViewModel {

    func handleFingerInputGesture(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        on view: UIView
    ) {
        defer {
            touchManager.removeTouchPointsFromTouchPointsDictionaryIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                prepareNextDrawing()
            }
        }

        guard inputManager.updateCurrentInput(.finger) != .pencil else { return }

        touchManager.appendFingerTouchesToTouchPointsDictionary(event, in: view)

        let newState: ActionState = .init(from: touchManager.touchPointsDictionary)

        switch actionManager.updateState(newState) {
        case .drawing:
            guard
                let hashValue = touchManager.hashValueForFingerDrawing,
                let touchPhase = touchManager.getLatestTouchPhase(with: hashValue)
            else { return }

            let isTouchEnded = touchPhase == .ended

            if isTouchEnded {
                registerDrawingUndoAction()
            }

            drawing.initDrawingIfHashValueIsNil(
                lineDrawing: smoothLineDrawing,
                hashValue: hashValue
            )

            let touchPoints = drawing.getNewTouchPoints(
                from: touchManager,
                with: smoothLineDrawing
            )

            let dotPoints = touchPoints.map {
                DotPoint(
                    touchPoint: $0,
                    matrix: transforming.matrix,
                    frameSize: frameSize,
                    textureSize: textureSize
                )
            }

            smoothLineDrawing.appendToIterator(dotPoints)

            if isTouchEnded {
                smoothLineDrawing.appendLastTouchToSmoothCurveIterator()
            }

            let lineSegment = drawing.makeLineSegment(
                from: smoothLineDrawing.iterator,
                with: .init(drawingTool),
                touchPhase: touchPhase
            )

            addCommandsDrawingSegmentOnCanvas(
                lineSegment: lineSegment,
                isTouchEnded: isTouchEnded
            )

            pauseDisplayLinkLoop(isTouchEnded)

            if isTouchEnded {
                smoothLineDrawing.clearIterator()
            }

        case .transforming:
            guard
                let hashValues = transforming.getHashValues(from: touchManager),
                let touchPoints = transforming.getTouchPoints(from: touchManager, using: hashValues)
            else { return }

            if transforming.isInitializationRequired {
                transforming.initTransforming(hashValues: hashValues)
            }

            transforming.transformCanvas(touchPoints: (touchPoints.0, touchPoints.1))

            if transforming.isTouchEnded {
                transforming.finishTransforming()
                touchManager.clearTouchPointsDictionary()
            }

            pauseDisplayLinkLoop(transforming.isTouchEnded)

        default:
            break
        }
    }

    func handlePencilInputGesture(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        on view: UIView
    ) {
        defer {
            touchManager.removeTouchPointsFromTouchPointsDictionaryIfTouchPhaseIsEnded(touches: touches)
            if touchManager.isEmpty {
                prepareNextDrawing()
            }
        }

        if inputManager.state == .finger {
            prepareNextDrawing()
            clearActions()
        }
        inputManager.updateCurrentInput(.pencil)

        touchManager.appendPencilTouchesToTouchPointsDictionary(event, in: view)

        guard
            let hashValue = touchManager.hashValueForPencilDrawing,
            let touchPhase = touchManager.getLatestTouchPhase(with: hashValue)
        else {
            return
        }

        let isTouchEnded = touchPhase == .ended

        if isTouchEnded {
            registerDrawingUndoAction()
        }

        drawing.initDrawingIfHashValueIsNil(
            lineDrawing: lineDrawing,
            hashValue: hashValue
        )

        let touchPoints = drawing.getNewTouchPoints(
            from: touchManager,
            with: lineDrawing
        )

        let dotPoints = touchPoints.map {
            DotPoint(
                touchPoint: $0,
                matrix: transforming.matrix,
                frameSize: frameSize,
                textureSize: textureSize
            )
        }

        lineDrawing.appendToIterator(dotPoints)

        let lineSegment = drawing.makeLineSegment(
            from: lineDrawing.iterator,
            with: .init(drawingTool),
            touchPhase: touchPhase
        )

        addCommandsDrawingSegmentOnCanvas(
            lineSegment: lineSegment,
            isTouchEnded: isTouchEnded
        )

        pauseDisplayLinkLoop(isTouchEnded)

        if isTouchEnded {
            lineDrawing.clearIterator()
        }
    }

}

extension CanvasViewModel {

    private func addCommandsDrawingSegmentOnCanvas(
        lineSegment: LineSegment,
        isTouchEnded: Bool
    ) {
        guard let delegate else { return }

        drawing.addDrawLineSegmentCommands(
            with: lineSegment,
            on: layerManager,
            to: delegate.commandBuffer
        )

        if isTouchEnded {
            drawing.addFinishDrawingCommands(
                on: layerManager,
                to: delegate.commandBuffer
            )
            touchManager.clearTouchPointsDictionary()
        }

        layerManager.addMergeDrawingLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: delegate.rootTexture,
            to: delegate.commandBuffer)
    }

}

extension CanvasViewModel {

    private func clearActions() {
        lineDrawing.clearIterator()
        smoothLineDrawing.clearIterator()
        transforming.clearTransforming()
        layerManager.clearDrawingLayer()
        delegate?.clearCommandBuffer()

        delegate?.refreshCanvasByCallingSetNeedsDisplay()
    }

    private func prepareNextDrawing() {
        touchManager.clearTouchPointsDictionary()
        inputManager.clear()
        actionManager.clear()
    }

}

extension CanvasViewModel {

    func didTapResetTransformButton() {
        transforming.setMatrix(.identity)
        delegate?.refreshCanvasByCallingSetNeedsDisplay()
    }

    func didTapNewCanvasButton() {

        projectName = Calendar.currentDate

        transforming.setMatrix(.identity)
        layerManager.initLayers(with: drawing.textureSize)

        clearUndoSubject.send()

        refreshCanvasWithMergingAllLayers()
    }

}

extension CanvasViewModel {

    func registerDrawingUndoAction() {
        guard
            let delegate,
            layerManager.layers.count != 0
        else { return }

        delegate.registerDrawingUndoAction(with: undoObject)

        layerManager.updateSelectedLayerTextureWithNewAddressTexture()
    }

}

extension CanvasViewModel {

    func refreshCanvas(using undoObject: UndoObject) {
        layerManager.initLayers(undoObject: undoObject)

        refreshCanvasWithMergingAllLayers()
    }

    func refreshCanvasWithMergingAllLayers() {
        guard let delegate else { return }

        layerManager.addMergeUnselectedLayersCommands(
            to: delegate.commandBuffer
        )
        refreshCanvasWithMergingDrawingLayers()
    }

    func refreshCanvasWithMergingDrawingLayers() {
        guard let delegate else { return }

        layerManager.addMergeDrawingLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: delegate.rootTexture,
            to: delegate.commandBuffer)

        delegate.refreshCanvasByCallingSetNeedsDisplay()
    }

    /// Start or stop the display link loop.
    func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if pauseDisplayLinkSubject.value == false {
                // Pause the display link after updating the display.
                delegate?.refreshCanvasByCallingSetNeedsDisplay()
                pauseDisplayLinkSubject.send(true)
            }

        } else {
            if pauseDisplayLinkSubject.value == true {
                pauseDisplayLinkSubject.send(false)
            }
        }
    }

}
