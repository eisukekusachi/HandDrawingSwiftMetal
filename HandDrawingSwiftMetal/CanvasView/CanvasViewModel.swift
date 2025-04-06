//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit
import SwiftUI

final class CanvasViewModel {

    let textureLayers = TextureLayers()

    let drawingTool = CanvasDrawingToolStatus()

    var frameSize: CGSize = .zero {
        didSet {
            renderer.frameSize = frameSize
        }
    }

    /// A name of the file to be saved
    var projectName: String = Calendar.currentDate

    var requestShowingActivityIndicatorPublisher: AnyPublisher<Bool, Never> {
        requestShowingActivityIndicatorSubject.eraseToAnyPublisher()
    }

    var requestShowingAlertPublisher: AnyPublisher<String, Never> {
        requestShowingAlertSubject.eraseToAnyPublisher()
    }

    var requestShowingToastPublisher: AnyPublisher<ToastModel, Never> {
        requestShowingToastSubject.eraseToAnyPublisher()
    }

    var requestShowingLayerViewPublisher: AnyPublisher<Bool, Never> {
        requestShowingLayerViewSubject.eraseToAnyPublisher()
    }

    var refreshCanvasPublisher: AnyPublisher<CanvasModel, Never> {
        refreshCanvasSubject.eraseToAnyPublisher()
    }

    var updateUndoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateUndoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }
    var updateRedoButtonIsEnabledState: AnyPublisher<Bool, Never> {
        updateRedoButtonIsEnabledStateSubject.eraseToAnyPublisher()
    }

    var isLayerViewVisible: Bool {
        requestShowingLayerViewSubject.value
    }

    /// A class for handling finger input values
    private let fingerScreenStrokeData = FingerScreenStrokeData()
    /// A class for handling Apple Pencil inputs
    private let pencilScreenStrokeData = PencilScreenStrokeData()

    /// An iterator for real-time drawing
    private var drawingCurveIterator: DrawingCurveIterator?

    /// A texture set for real-time drawing
    private var drawingTextureSet: CanvasDrawingTextureSet?
    /// A brush texture set for real-time drawing
    private let drawingBrushTextureSet = CanvasDrawingBrushTextureSet()
    /// An eraser texture set for real-time drawing
    private let drawingEraserTextureSet = CanvasDrawingEraserTextureSet()

    /// A display link for real-time drawing
    private var drawingDisplayLink = CanvasDrawingDisplayLink()

    private var renderer = CanvasRenderer()

    private let transformer = CanvasTransformer()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    private let updateUndoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private let updateRedoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private var localRepository: LocalRepository!

    private var textureRepository: TextureRepository!

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        textureRepository: TextureRepository = SingletonTextureInMemoryRepository.shared,
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
        self.textureRepository = textureRepository
        self.localRepository = localRepository

        drawingTool.setDrawingTool(.brush)

        subscribe()
    }

    private func subscribe() {
        drawingDisplayLink.canvasDrawingPublisher
            .sink { [weak self] in
                self?.updateCanvasWithDrawing()
            }
            .store(in: &cancellables)

        Publishers.Merge(
            drawingBrushTextureSet.canvasDrawFinishedPublisher,
            drawingEraserTextureSet.canvasDrawFinishedPublisher
        )
        .sink { [weak self] in
            self?.completeCanvasUpdateWithDrawing()
        }
        .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush: self.drawingTextureSet = self.drawingBrushTextureSet
                case .eraser: self.drawingTextureSet = self.drawingEraserTextureSet
                }
            }
            .store(in: &cancellables)

        drawingTool.brushColorPublisher
            .sink { [weak self] color in
                self?.drawingBrushTextureSet.setBlushColor(color)
            }
            .store(in: &cancellables)

        drawingTool.eraserAlphaPublisher
            .sink { [weak self] alpha in
                self?.drawingEraserTextureSet.setEraserAlpha(alpha)
            }
            .store(in: &cancellables)

        textureLayers.didFinishInitializationPublisher
            .sink { [weak self] textureSize in
                self?.initTextures(textureSize: textureSize)
            }
            .store(in: &cancellables)

        textureLayers.updateCanvasAfterTextureLayerUpdatesPublisher
            .sink { [weak self] _ in
                guard let `self` else { return }
                self.renderer.updateCanvasAfterUpdatingAllTextures(
                    textureLayers: self.textureLayers,
                    commandBuffer: self.renderer.commandBuffer
                )
            }
            .store(in: &cancellables)

        textureLayers.updateCanvasPublisher
            .sink { [weak self] in
                self?.updateCanvas()
            }
            .store(in: &cancellables)

        drawingTool.backgroundColorPublisher.assign(to: \.backgroundColor, on: renderer).store(in: &cancellables)

        transformer.matrixPublisher.assign(to: \.matrix, on: renderer) .store(in: &cancellables)
    }

    func initCanvas(using model: CanvasModel) {
        guard let drawableSize = renderer.renderTextureSize else { return }

        projectName = model.projectName
        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        textureLayers.restoreLayers(from: model, drawableSize: drawableSize)
    }

    private func initTextures(textureSize: CGSize) {
        guard let commandBuffer = renderer.commandBuffer else { return }

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)
        renderer.updateCanvasAfterUpdatingAllTextures(
            textureLayers: textureLayers,
            commandBuffer: commandBuffer
        )
    }

}

extension CanvasViewModel {

    func onViewDidLoad(
        canvasView: CanvasViewProtocol
    ) {
        renderer.setCanvas(canvasView)
    }

    func onViewDidAppear(
        model: CanvasModel,
        drawableTextureSize: CGSize
    ) {
        if !renderer.hasTextureBeenInitialized {
            initCanvas(using: model)
        }
    }

    func onUpdateRenderTexture() {
        // Redraws the canvas when the device rotates and the canvas size changes.
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        renderer.updateCanvas(
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard inputDevice.update(.finger) != .pencil else { return }

        fingerScreenStrokeData.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch screenTouchGesture.update(fingerScreenStrokeData.touchArrayDictionary) {
        case .drawing:
            if shouldCreateFingerDrawingCurveIteratorInstance() {
                drawingCurveIterator = DrawingCurveFingerIterator()
            }

            fingerScreenStrokeData.setActiveDictionaryKeyIfNil()

            drawCurveOnCanvas(fingerScreenStrokeData.latestTouchPoints)

        case .transforming: transformCanvas()
        default: break
        }

        fingerScreenStrokeData.removeEndedTouchArrayFromDictionary()

        if UITouch.isAllFingersReleasedFromScreen(touches: touches, with: event) {
            resetAllInputParameters()
        }
    }

    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        // Cancel finger drawing and switch to pen drawing if present
        if inputDevice.status == .finger {
            cancelFingerDrawing()
        }
        inputDevice.update(.pencil)

        pencilScreenStrokeData.setLatestEstimatedTouchPoint(
            estimatedTouches
                .filter({ $0.type == .pencil })
                .sorted(by: { $0.timestamp < $1.timestamp })
                .last
                .map { .init(touch: $0, view: view) }
        )
    }

    func onPencilGestureDetected(
        actualTouches: Set<UITouch>,
        view: UIView
    ) {
        if shouldCreatePencilDrawingCurveIteratorInstance(actualTouches: actualTouches) {
            drawingCurveIterator = DrawingCurvePencilIterator()
        }

        pencilScreenStrokeData.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        drawCurveOnCanvas(pencilScreenStrokeData.latestActualTouchPoints)
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {}
    func didTapRedoButton() {}

    func didTapLayerButton() {
        // Toggle the visibility of `TextureLayerView`
        requestShowingLayerViewSubject.send(!requestShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton() {
        guard let commandBuffer = renderer.commandBuffer else { return }
        transformer.setMatrix(.identity)
        renderer.refreshCanvasView(commandBuffer)
    }

    func didTapNewCanvasButton() {
        transformer.setMatrix(.identity)
        initCanvas(
            using: .init(textureSize: renderer.textureSize)
        )
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        guard let canvasTexture = renderer.canvasTexture else { return }
        saveFile(canvasTexture: canvasTexture)
    }

    // MARK: Layers
    func didTapLayer(layer: TextureLayerModel) {
        textureLayers.selectLayer(layer.id)
    }
    func didTapAddLayerButton() {
        textureLayers.insertLayer(
            textureSize: renderer.textureSize,
            at: textureLayers.newIndex
        )
    }
    func didTapRemoveLayerButton() {
        textureLayers.removeLayer()
    }
    func didMoveLayers(fromOffsets: IndexSet, toOffset: Int) {
        textureLayers.moveLayer(fromListOffsets: fromOffsets, toListOffset: toOffset)
    }
    func didTapLayerVisibility(layer: TextureLayerModel, isVisible: Bool) {
        textureLayers.updateLayer(id: layer.id, isVisible: isVisible)
    }

    func didStartChangingLayerAlpha(layer: TextureLayerModel) {}

    func didChangeLayerAlpha(layer: TextureLayerModel, value: Int) {
        textureLayers.updateLayer(id: layer.id, alpha: value)
    }
    func didFinishChangingLayerAlpha(layer: TextureLayerModel) {}

    func didEditLayerTitle(layer: TextureLayerModel, title: String) {
        textureLayers.updateLayer(id: layer.id, title: title)
    }

}

extension CanvasViewModel {

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard let drawableSize = renderer.renderTextureSize else { return }

        drawingCurveIterator?.append(
            points: screenTouchPoints.map {
                .init(
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: renderer.textureSize,
                    drawableSize: drawableSize,
                    frameSize: renderer.frameSize,
                    diameter: CGFloat(drawingTool.diameter)
                )
            },
            touchPhase: screenTouchPoints.lastTouchPhase
        )

        drawingDisplayLink.updateCanvasWithDrawing(
            isCurrentlyDrawing: drawingCurveIterator?.isCurrentlyDrawing ?? false
        )
    }

    private func transformCanvas() {
        guard let commandBuffer = renderer.commandBuffer else { return }

        transformer.initTransformingIfNeeded(
            fingerScreenStrokeData.touchArrayDictionary
        )

        if fingerScreenStrokeData.isAllFingersOnScreen {
            transformer.transformCanvas(
                screenCenter: .init(
                    x: renderer.frameSize.width * 0.5,
                    y: renderer.frameSize.height * 0.5
                ),
                fingerScreenStrokeData.touchArrayDictionary
            )
        } else {
            transformer.finishTransforming()
        }

        renderer.refreshCanvasView(commandBuffer)
    }

}

extension CanvasViewModel {
    // Since the pencil takes priority, even if `drawingCurveIterator` contains an instance,
    // it will be overwritten when touchBegan occurs.
    private func shouldCreatePencilDrawingCurveIteratorInstance(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    // If `drawingCurveIterator` is nil, an instance of `FingerDrawingCurveIterator` will be set.
    private func shouldCreateFingerDrawingCurveIteratorInstance() -> Bool {
        drawingCurveIterator == nil
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerScreenStrokeData.reset()
        pencilScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()
    }

    private func cancelFingerDrawing() {
        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearDrawingTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()

        renderer.resetCommandBuffer()

        if let commandBuffer = renderer.commandBuffer {
            renderer.refreshCanvasView(commandBuffer)
        }
    }

    private func updateCanvas() {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        renderer.updateCanvas(
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

    private func updateCanvasWithDrawing() {
        guard
            let drawingCurveIterator,
            let selectedLayer = textureLayers.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        drawingTextureSet?.drawCurvePoints(
            drawingCurveIterator: drawingCurveIterator,
            withBackgroundTexture: self.renderer.selectedTexture,
            withBackgroundColor: .clear,
            with: commandBuffer
        )

        renderer.updateCanvas(
            realtimeDrawingTexture: self.drawingTextureSet?.drawingSelectedTexture,
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }
    private func completeCanvasUpdateWithDrawing() {
        resetAllInputParameters()

        renderer.commandBuffer?.addCompletedHandler { _ in
            DispatchQueue.main.async { [weak self] in
                guard
                    let selectedTexture = self?.renderer.selectedTexture,
                    let selectedTextureId = self?.textureLayers.selectedLayer?.id
                else { return }

                self?.renderer.renderTextureToLayerInRepository(
                    texture: selectedTexture,
                    targetTextureId: selectedTextureId
                ) { [weak self] texture in
                    self?.textureLayers.updateThumbnail(texture)
                }
            }
        }
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        localRepository.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath),
            textureRepository: textureRepository
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: { [weak self] canvasModel in
            self?.refreshCanvasSubject.send(canvasModel)
        })
        .store(in: &cancellables)
    }

    private func saveFile(canvasTexture: MTLTexture) {
        localRepository.saveDataToDocuments(
            renderTexture: canvasTexture,
            textureLayers: textureLayers,
            textureRepository: textureRepository,
            drawingTool: drawingTool,
            to: URL.getZipFileURL(projectName: projectName)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.requestShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.requestShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: {})
        .store(in: &cancellables)
    }

}
