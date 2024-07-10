//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

enum CanvasViewModelError: Error {
    case failedToApplyData
}

final class CanvasViewModel {

    var renderTarget: MTKRenderTextureProtocol?

    let drawing = Drawing()

    let transforming = Transforming()

    let layerManager = ImageLayerManager()

    let layerUndoManager = LayerUndoManager()

    let drawingTool = DrawingToolModel()

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

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var zipFileNameName: String {
        projectName + "." + URL.zipSuffix
    }

    var pauseDisplayLinkPublisher: AnyPublisher<Bool, Never> {
        pauseDisplayLinkSubject.eraseToAnyPublisher()
    }

    var requestShowingActivityIndicatorPublisher: AnyPublisher<Bool, Never> {
        requestShowingActivityIndicatorSubject.eraseToAnyPublisher()
    }

    var requestShowingAlertPublisher: AnyPublisher<String, Never> {
        requestShowingAlertSubject.eraseToAnyPublisher()
    }

    var requestShowingToastPublisher: AnyPublisher<ToastModel, Never> {
        requestShowingToastSubject.eraseToAnyPublisher()
    }

    var requestShowingLayerViewPublisher: AnyPublisher<Void, Never> {
        requestShowingLayerViewSubject.eraseToAnyPublisher()
    }

    var refreshCanvasPublisher: AnyPublisher<CanvasModel, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    private let lineDrawing = LineDrawing()
    private let smoothLineDrawing = SmoothLineDrawing()

    private let touchManager = TouchManager()
    private let actionManager = ActionManager()

    private var localRepository: LocalRepository?

    private let pauseDisplayLinkSubject = CurrentValueSubject<Bool, Never>(true)

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = PassthroughSubject<Void, Never>()

    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
        self.localRepository = localRepository

        layerUndoManager.addUndoObjectToUndoStackPublisher
            .sink { [weak self] in
                guard let `self` else { return }
                self.layerUndoManager.addUndoObject(
                    undoObject: UndoObject(
                        index: self.layerManager.index,
                        layers: self.layerManager.layers
                    ),
                    layerManager: self.layerManager
                )
                self.layerManager.updateTextureAddress()
            }
            .store(in: &cancellables)

        layerUndoManager.refreshCanvasPublisher
            .sink { [weak self] undoObject in
                self?.layerManager.initLayers(
                    index: undoObject.index,
                    layers: undoObject.layers
                )
                self?.refreshCanvasWithMergingAllLayers()
            }
            .store(in: &cancellables)

        layerUndoManager.updateUndoActivity()

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                self?.layerManager.setDrawingLayer(tool)
            }
            .store(in: &cancellables)

        drawingTool.setDrawingTool(.brush)
    }

    func initCanvas(
        textureSize: CGSize,
        renderTarget: MTKRenderTextureProtocol
    ) {
        layerManager.initialize(textureSize: textureSize)

        renderTarget.initRenderTexture(textureSize: textureSize)

        layerManager.updateUnselectedLayers(
            to: renderTarget.commandBuffer
        )
        layerManager.mergeAllLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: renderTarget.renderTexture!,
            renderTarget.commandBuffer
        )

        renderTarget.setNeedsDisplay()
    }

    func apply(
        model: CanvasModel,
        to renderTarget: MTKRenderTextureProtocol
    ) {
        projectName = model.projectName

        layerManager.initialize(
            textureSize: model.textureSize,
            layerIndex: model.layerIndex,
            layers: model.layers
        )

        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        renderTarget.initRenderTexture(textureSize: model.textureSize)

        layerManager.updateUnselectedLayers(
            to: renderTarget.commandBuffer
        )
        layerManager.mergeAllLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: renderTarget.renderTexture!,
            renderTarget.commandBuffer
        )

        renderTarget.setNeedsDisplay()
    }

}

extension CanvasViewModel {
    func onDrawableSizeChanged(
        _ drawableTextureSize: CGSize,
        renderTarget: MTKRenderTextureProtocol
    ) {
        // Initialize the canvas here using the drawableTextureSize
        // if the renderTexture's texture is nil
        // by the time `func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)` is called.
        guard
            renderTarget.renderTexture == nil
        else { return }

        initCanvas(
            textureSize: drawableTextureSize,
            renderTarget: renderTarget
        )
    }

    func handleFingerInputGesture(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        on view: UIView
    ) {
        defer {
            touchManager.removeValuesOnTouchesEnded(touches: touches)

            if touchManager.isAllFingersReleased(touches: touches, with: event) {
                initDrawingParameters()
            }
        }

        guard inputManager.updateCurrentInput(.finger) != .pencil else { return }

        touchManager.appendFingerTouchesToTouchPointsDictionary(event, in: view)

        let newState: ActionState = .init(from: touchManager.touchPointsDictionary)

        switch actionManager.updateState(newState) {
        case .drawing:
            guard
                let renderTarget,
                let hashValue = touchManager.hashValueForFingerDrawing,
                let touchPhase = touchManager.getLatestTouchPhase(with: hashValue)
            else { return }

            let isTouchEnded = touchPhase == .ended

            if isTouchEnded {
                layerUndoManager.addUndoObjectToUndoStack()
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
                    touchPoint: $0.getScaledTouchPoint(
                        renderTextureSize: renderTarget.renderTexture?.size ?? .zero,
                        drawableSize: renderTarget.viewDrawable?.texture.size ?? .zero
                    ),
                    matrix: transforming.matrix,
                    frameSize: frameSize,
                    textureSize: renderTarget.renderTexture?.size ?? .zero,
                    drawableSize: renderTarget.viewDrawable?.texture.size ?? .zero

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

            drawSegmentOnCanvas(
                lineSegment: lineSegment,
                on: renderTarget.renderTexture,
                to: renderTarget.commandBuffer
            )

            if isTouchEnded {
                initDrawingParameters()
            }

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
                initDrawingParameters()
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
            touchManager.removeValuesOnTouchesEnded(touches: touches)

            if touchManager.isAllFingersReleased(touches: touches, with: event) {
                initDrawingParameters()
            }
        }

        guard
            let renderTarget
        else { return }

        if inputManager.state == .finger {
            initDrawingParameters()

            layerManager.clearDrawingLayer()

            renderTarget.clearCommandBuffer()
            renderTarget.setNeedsDisplay()
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
            layerUndoManager.addUndoObjectToUndoStack()
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
                touchPoint: $0.getScaledTouchPoint(
                    renderTextureSize: renderTarget.renderTexture?.size ?? .zero,
                    drawableSize: renderTarget.viewDrawable?.texture.size ?? .zero
                ),
                matrix: transforming.matrix,
                frameSize: frameSize,
                textureSize: renderTarget.renderTexture?.size ?? .zero,
                drawableSize: renderTarget.viewDrawable?.texture.size ?? .zero
            )
        }

        lineDrawing.appendToIterator(dotPoints)

        // TODO: Delete it once actual values are used instead of estimated ones.
        lineDrawing.setInaccurateAlphaToZero()

        let lineSegment = drawing.makeLineSegment(
            from: lineDrawing.iterator,
            with: .init(drawingTool),
            touchPhase: touchPhase
        )

        drawSegmentOnCanvas(
            lineSegment: lineSegment,
            on: renderTarget.renderTexture,
            to: renderTarget.commandBuffer
        )

        if isTouchEnded {
            initDrawingParameters()
        }

        pauseDisplayLinkLoop(isTouchEnded)
    }

}

extension CanvasViewModel {

    private func initDrawingParameters() {
        touchManager.clearTouchPointsDictionary()

        inputManager.clear()
        actionManager.clear()

        lineDrawing.clearIterator()
        smoothLineDrawing.clearIterator()
        transforming.clearTransforming()
    }

    private func drawSegmentOnCanvas(
        lineSegment: LineSegment,
        on renderTexture: MTLTexture?,
        to commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let renderTexture,
            let commandBuffer
        else { return }

        drawing.addDrawLineSegmentCommands(
            with: lineSegment,
            on: layerManager,
            to: commandBuffer
        )

        if lineSegment.touchPhase == .ended {
            drawing.addFinishDrawingCommands(
                on: layerManager,
                to: commandBuffer
            )
        }

        layerManager.mergeAllLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: renderTexture,
            commandBuffer)
    }

}

extension CanvasViewModel {

    func refreshCanvasWithMergingAllLayers() {
        guard 
            let renderTarget
        else { return }

        layerManager.updateUnselectedLayers(
            to: renderTarget.commandBuffer
        )
        refreshCanvasWithMergingDrawingLayers()
    }

    func refreshCanvasWithMergingDrawingLayers() {
        guard 
            let renderTarget,
            let renderTexture = renderTarget.renderTexture
        else { return }

        layerManager.mergeAllLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: renderTexture,
            renderTarget.commandBuffer
        )

        renderTarget.setNeedsDisplay()
    }

    /// Start or stop the display link loop.
    private func pauseDisplayLinkLoop(_ pause: Bool) {
        if pause {
            if pauseDisplayLinkSubject.value == false {
                // Pause the display link after updating the display.
                renderTarget?.setNeedsDisplay()
                pauseDisplayLinkSubject.send(true)
            }

        } else {
            if pauseDisplayLinkSubject.value == true {
                pauseDisplayLinkSubject.send(false)
            }
        }
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {
        layerUndoManager.undo()
    }
    func didTapRedoButton() {
        layerUndoManager.redo()
    }

    func didTapLayerButton() {
        Task {
            try? await layerManager.updateCurrentThumbnail()

            DispatchQueue.main.async { [weak self] in
                self?.requestShowingLayerViewSubject.send()
            }
        }
    }

    func didTapResetTransformButton() {
        transforming.setMatrix(.identity)
        renderTarget?.setNeedsDisplay()
    }

    func didTapNewCanvasButton() {

        projectName = Calendar.currentDate

        transforming.setMatrix(.identity)
        layerManager.initialize(textureSize: drawing.textureSize)

        layerUndoManager.clear()

        refreshCanvasWithMergingAllLayers()
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        saveFile()
    }

    // MARK: Layers
    func didTapLayer(layer: ImageLayerCellItem) {
        layerManager.updateIndex(layer)
        refreshCanvasWithMergingAllLayers()
    }
    func didTapAddLayerButton() {
        layerUndoManager.addUndoObjectToUndoStack()

        layerManager.addNewLayer()
        refreshCanvasWithMergingAllLayers()
    }
    func didTapRemoveLayerButton() {
        guard
            layerManager.layers.count > 1,
            let layer = layerManager.selectedLayer
        else { return }

        layerUndoManager.addUndoObjectToUndoStack()

        layerManager.removeLayer(layer)
        refreshCanvasWithMergingAllLayers()
    }
    func didTapLayerVisibility(layer: ImageLayerCellItem, isVisible: Bool) {
        layerManager.update(layer, isVisible: isVisible)
        refreshCanvasWithMergingAllLayers()
    }
    func didChangeLayerAlpha(layer: ImageLayerCellItem, value: Int) {
        layerManager.update(layer, alpha: value)
        refreshCanvasWithMergingDrawingLayers()
    }
    func didEditLayerTitle(layer: ImageLayerCellItem, title: String) {
        layerManager.updateTitle(layer, title)
    }
    func didMoveLayers(layer: ImageLayerCellItem, source: IndexSet, destination: Int) {
        layerUndoManager.addUndoObjectToUndoStack()

        layerManager.moveLayer(
            fromOffsets: source,
            toOffset: destination
        )
        refreshCanvasWithMergingAllLayers()
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        localRepository?.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription) }
        }, receiveValue: { [weak self] response in
            self?.refreshCanvasSubject.send(response)
        })
        .store(in: &cancellables)
    }

    private func saveFile() {
        guard
            let canvasTexture = renderTarget?.renderTexture
        else { return }

        localRepository?.saveDataToDocuments(
            data: .init(
                canvasTexture: canvasTexture,
                layerManager: layerManager,
                drawingTool: drawingTool
            ),
            to: URL.documents.appendingPathComponent(zipFileNameName)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription) }
        }, receiveValue: {})
        .store(in: &cancellables)
    }

}
