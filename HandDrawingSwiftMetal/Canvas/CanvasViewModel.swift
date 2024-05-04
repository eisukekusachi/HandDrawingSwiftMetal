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

    func refreshCanvasByCallingSetNeedsDisplay()

}

enum CanvasViewModelError: Error {
    case failedToApplyData
}

class CanvasViewModel {

    var delegate: CanvasViewModelDelegate?

    let drawing = Drawing()

    let transforming = Transforming()

    let layerManager = LayerManager()
    let layerViewPresentation = LayerViewPresentation()

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
                self.layerManager.updateSelectedLayerTextureWithNewAddressTexture()
            }
            .store(in: &cancellables)

        layerUndoManager.refreshCanvasPublisher
            .sink { [weak self] undoObject in
                self?.refreshCanvas(using: undoObject)
            }
            .store(in: &cancellables)

        layerUndoManager.updateUndoActivity()

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

    func applyCanvasDataToCanvas(
        data: CanvasEntity?,
        fileName: String,
        folderURL: URL
    ) throws {
        guard
            let data,
            let device: MTLDevice = MTLCreateSystemDefaultDevice()
        else {
            throw CanvasViewModelError.failedToApplyData
        }

        let layerEntityForExportingArray: [LayerEntityForExporting] = data.layers

        let layers: [LayerEntity] = try layerEntityForExportingArray.map({ $0 }).convertToLayerEntity(
            device: device,
            textureSize: data.textureSize,
            folderURL: folderURL
        )

        layerManager.initLayers(
            index: data.layerIndex,
            layers: layers
        )

        drawingTool.setBrushDiameter(data.brushDiameter)
        drawingTool.setEraserDiameter(data.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: data.drawingTool))

        projectName = fileName
    }

}

extension CanvasViewModel {

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

            drawSegmentOnCanvas(
                lineSegment: lineSegment,
                on: delegate?.rootTexture,
                to: delegate?.commandBuffer
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

        if inputManager.state == .finger {
            initDrawingParameters()

            layerManager.clearDrawingLayer()

            delegate?.clearCommandBuffer()
            delegate?.refreshCanvasByCallingSetNeedsDisplay()
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
                touchPoint: $0,
                matrix: transforming.matrix,
                frameSize: frameSize,
                textureSize: textureSize
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
            on: delegate?.rootTexture,
            to: delegate?.commandBuffer
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
        on rootTexture: MTLTexture?,
        to commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let rootTexture,
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

        layerManager.mergeDrawingLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: rootTexture,
            to: commandBuffer)
    }

}

extension CanvasViewModel {

    func refreshCanvas(using undoObject: UndoObject) {
        layerManager.initLayers(undoObject: undoObject)

        refreshCanvasWithMergingAllLayers()
    }

    func refreshCanvasWithMergingAllLayers() {
        guard let delegate else { return }

        layerManager.mergeUnselectedLayers(
            to: delegate.commandBuffer
        )
        refreshCanvasWithMergingDrawingLayers()
    }

    func refreshCanvasWithMergingDrawingLayers() {
        guard let delegate else { return }

        layerManager.mergeDrawingLayers(
            backgroundColor: drawingTool.backgroundColor,
            onto: delegate.rootTexture,
            to: delegate.commandBuffer)

        delegate.refreshCanvasByCallingSetNeedsDisplay()
    }

    /// Start or stop the display link loop.
    private func pauseDisplayLinkLoop(_ pause: Bool) {
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

extension CanvasViewModel {

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
        delegate?.refreshCanvasByCallingSetNeedsDisplay()
    }

    func didTapNewCanvasButton() {

        projectName = Calendar.currentDate

        transforming.setMatrix(.identity)
        layerManager.initLayers(with: drawing.textureSize)

        layerUndoManager.clear()

        refreshCanvasWithMergingAllLayers()
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        saveFile()
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        localRepository?.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath),
            canvasViewModel: self
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

    private func saveFile() {
        guard
            let canvasTexture = delegate?.rootTexture
        else { return }

        localRepository?.saveDataToDocuments(
            data: ExportCanvasData.init(
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
