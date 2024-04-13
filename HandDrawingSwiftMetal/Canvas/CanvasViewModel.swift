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

    func callSetNeedsDisplayOnCanvasView()

}

class CanvasViewModel {

    var delegate: CanvasViewModelDelegate?

    let drawing = Drawing()

    let transforming = Transforming()

    let layerManager = LayerManager()

    let drawingTool = DrawingToolModel()

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

            drawing.textureSize = textureSize

            layerManager.setTextureSize(textureSize)
            mergeAllLayersToRootTexture()

            delegate?.callSetNeedsDisplayOnCanvasView()
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var undoObject: UndoObject {
        return UndoObject(
            index: layerManager.index,
            layers: layerManager.layers
        )
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    var addUndoObjectToUndoStackPublisher: AnyPublisher<Void, Never> {
        addUndoObjectToUndoStackSubject.eraseToAnyPublisher()
    }

    var clearUndoPublisher: AnyPublisher<Void, Never> {
        clearUndoSubject.eraseToAnyPublisher()
    }

    private let lineDrawing = LineDrawing()
    private let smoothLineDrawing = SmoothLineDrawing()

    private let touchManager = TouchManager()
    private let actionManager = ActionManager()

    /// A protocol for managing file input and output
    private (set) var fileIO: FileIO!

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let addUndoObjectToUndoStackSubject = PassthroughSubject<Void, Never>()

    private let clearUndoSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        layerManager.addUndoObjectToUndoStackPublisher
            .subscribe(addUndoObjectToUndoStackSubject)
            .store(in: &cancellables)

        layerManager.mergeAllLayersToRootTexturePublisher
            .sink { [weak self] in
                self?.mergeAllLayersToRootTexture()
                self?.delegate?.callSetNeedsDisplayOnCanvasView()
            }
            .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                self?.layerManager.setDrawingLayer(tool)
            }
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
            guard let lineSegment: LineSegment = drawing.makeLineSegment(
                from: touchManager,
                with: smoothLineDrawing,
                matrix: transforming.matrix,
                parameters: .init(drawingTool)
            ) 
            else { return }

            if lineSegment.touchPhase == .ended {
                addUndoObjectToUndoStackSubject.send()
            }

            drawing.addDrawSegmentCommands(
                lineSegment,
                on: layerManager,
                to: delegate?.commandBuffer
            )

            mergeAllLayersToRootTexture()

            pauseDisplayLinkLoop(lineSegment.touchPhase == .ended)

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
            }

            pauseDisplayLinkLoop(transforming.isTouchEnded)

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

        guard let lineSegment: LineSegment = drawing.makeLineSegment(
            from: touchManager,
            with: lineDrawing,
            matrix: transforming.matrix,
            parameters: .init(drawingTool)
        ) 
        else { return }

        if lineSegment.touchPhase == .ended {
            addUndoObjectToUndoStackSubject.send()
        }

        drawing.addDrawSegmentCommands(
            lineSegment,
            on: layerManager,
            to: delegate?.commandBuffer
        )

        mergeAllLayersToRootTexture()

        pauseDisplayLinkLoop(lineSegment.touchPhase == .ended)
    }

}

extension CanvasViewModel {

    func didTapResetTransformButton() {
        transforming.resetTransforming(.identity)
        delegate?.callSetNeedsDisplayOnCanvasView()
    }

    func didTapNewCanvasButton() {

        clearUndoSubject.send()

        projectName = Calendar.currentDate

        transforming.resetTransforming(.identity)

        layerManager.setTextureSize(drawing.textureSize)

        mergeAllLayersToRootTexture()
        delegate?.callSetNeedsDisplayOnCanvasView()
    }

}

extension CanvasViewModel {

    func initTextureSizeIfSizeIsZero(frameSize: CGSize, drawableSize: CGSize) {
        if textureSize == .zero &&
           frameSize.isSameRatio(drawableSize) {
            textureSize = drawableSize
        }
    }

    func mergeAllLayersToRootTexture() {
        guard
            let rootTexture = delegate?.rootTexture,
            let commandBuffer = delegate?.commandBuffer
        else { return }

        layerManager.addMergeAllLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: rootTexture,
            to: commandBuffer)
    }

    /// Start or stop the display link loop.
    func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if pauseDisplayLinkSubject.value == false {
                // Pause the display link after updating the display.
                delegate?.callSetNeedsDisplayOnCanvasView()
                pauseDisplayLinkSubject.send(true)
            }

        } else {
            if pauseDisplayLinkSubject.value == true {
                pauseDisplayLinkSubject.send(false)
            }
        }
    }

}
