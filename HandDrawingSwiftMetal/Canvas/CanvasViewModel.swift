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

    func setCommandBufferToNil()

    func registerDrawingUndoAction(with undoObject: UndoObject)

    func callSetNeedsDisplayOnCanvasView()

}

class CanvasViewModel {

    var delegate: CanvasViewModelDelegate?

    let drawing = Drawing()

    let transforming = Transforming()

    let layerManager = LayerManager()

    let drawingTool = DrawingToolModel()

    let undoHistoryManager = UndoHistoryManager()

    let inputManager = InputManager()

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

    var undoObject: UndoObject {
        return UndoObject(
            index: layerManager.index,
            layers: layerManager.layers
        )
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
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

    private let clearUndoSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(fileIO: FileIO = FileIOImpl()) {
        self.fileIO = fileIO

        undoHistoryManager.addUndoObjectToUndoStackPublisher
            .sink { [weak self] in
                self?.registerDrawingUndoAction()
            }
            .store(in: &cancellables)

        layerManager.refreshCanvasWithMergingLayersPublisher
            .sink { [weak self] in
                self?.refreshCanvasWithMergingLayers()
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

}

extension CanvasViewModel {

    func handleFingerInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.touchPointsDictionary.isEmpty {
                prepareNextDrawing()
            }
        }

        guard inputManager.updateCurrentInput(.finger) != .pencil else { return }

        touchManager.appendFingerTouches(event, in: view)

        let newState: ActionState = .init(from: touchManager.touchPointsDictionary)

        switch actionManager.updateState(newState) {
        case .drawing:

            if let hashValue = touchManager.hashValueForFingerDrawing {
                drawing.initDrawingIfHashValueIsNil(
                    lineDrawing: smoothLineDrawing,
                    hashValue: hashValue
                )
            }

            guard
                let delegate,
                let lineSegment: LineSegment = drawing.makeLineSegment(
                    from: touchManager,
                    with: smoothLineDrawing,
                    matrix: transforming.matrix,
                    parameters: .init(drawingTool)
                )
            else { return }

            let isTouchEnded = lineSegment.touchPhase == .ended

            if isTouchEnded {
                registerDrawingUndoAction()
            }

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
                touchManager.clear()
            }

            addMergeLayersToRootTextureCommands(to: delegate.commandBuffer)

            pauseDisplayLinkLoop(isTouchEnded)

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
                touchManager.clear()
            }

            pauseDisplayLinkLoop(transforming.isTouchEnded)

        default:
            break
        }
    }

    func handlePencilInputGesture(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        defer {
            touchManager.removeIfTouchPhaseIsEnded(touches: touches)
            if touchManager.isEmpty {
                prepareNextDrawing()
            }
        }

        if inputManager.currentInput == .finger {
            prepareNextDrawing()
            resetActions()
        }
        inputManager.updateCurrentInput(.pencil)

        touchManager.appendPencilTouches(event, in: view)

        // Set a hash value for the type 'pencil'.
        if let hashValue = touchManager.hashValueForPencilDrawing {
            drawing.initDrawingIfHashValueIsNil(
                lineDrawing: lineDrawing,
                hashValue: hashValue
            )
        }

        guard 
            let delegate,
            let lineSegment: LineSegment = drawing.makeLineSegment(
                from: touchManager,
                with: lineDrawing,
                matrix: transforming.matrix,
                parameters: .init(drawingTool)
            )
        else { return }

        let isTouchEnded = lineSegment.touchPhase == .ended

        if isTouchEnded {
            registerDrawingUndoAction()
        }

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
            touchManager.clear()
        }

        addMergeLayersToRootTextureCommands(to: delegate.commandBuffer)

        pauseDisplayLinkLoop(isTouchEnded)
    }

    private func resetActions() {
        lineDrawing.finishDrawing()
        smoothLineDrawing.finishDrawing()

        transforming.cancelTransforming()

        layerManager.clearDrawingLayerTextures()

        delegate?.setCommandBufferToNil()
        delegate?.callSetNeedsDisplayOnCanvasView()
    }

    private func prepareNextDrawing() {
        touchManager.clear()
        inputManager.reset()
        actionManager.reset()
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

        layerManager.initLayers(with: drawing.textureSize)

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

    func addMergeLayersToRootTextureCommands(to commandBuffer: MTLCommandBuffer?) {
        guard
            let rootTexture = delegate?.rootTexture,
            let commandBuffer
        else { return }

        layerManager.addMergeLayersCommands(
            backgroundColor: drawingTool.backgroundColor,
            onto: rootTexture,
            to: commandBuffer)
    }

    func refreshCanvas(using undoObject: UndoObject) {
        layerManager.initLayers(undoObject: undoObject)

        refreshCanvasWithMergingAllLayers()
    }

    func refreshCanvasWithMergingAllLayers() {
        guard let delegate else { return }

        layerManager.addMergeUnselectedLayersCommands(
            to: delegate.commandBuffer
        )
        refreshCanvasWithMergingLayers()
    }

    func refreshCanvasWithMergingLayers() {
        guard let delegate else { return }

        addMergeLayersToRootTextureCommands(to: delegate.commandBuffer)

        delegate.callSetNeedsDisplayOnCanvasView()
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
