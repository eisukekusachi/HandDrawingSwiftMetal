//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
import Combine

final class CanvasViewModel {

    let textureLayers = TextureLayers()

    let drawingTool = CanvasDrawingToolStatus()

    var frameSize: CGSize = .zero

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

    private var drawingCurveIterator: DrawingCurveIterator?

    private let transformer = CanvasTransformer()

    private let inputDevice = CanvasInputDeviceStatus()

    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private var localRepository: LocalRepository?

    private var drawingDisplayLink = CanvasDrawingDisplayLink()

    private var canvasView: CanvasViewProtocol?

    /// A protocol for real-time drawing on a texture
    private var drawingTextureSet: CanvasDrawingTextureSet?
    /// A drawing texture with a brush
    private let drawingBrushTextureSet = CanvasDrawingBrushTextureSet()
    /// A drawing texture with an eraser
    private let drawingEraserTextureSet = CanvasDrawingEraserTextureSet()

    /// A texture that combines the texture of the currently selected layer and the `drawingTexture`
    private var currentTexture: MTLTexture?

    /// A texture that combines the background color, the texture of `TextureLayers` and `currentTexture`
    private var canvasTexture: MTLTexture?

    private let requestShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let requestShowingAlertSubject = PassthroughSubject<String, Never>()

    private let requestShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let requestShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let refreshCanvasSubject = PassthroughSubject<CanvasModel, Never>()

    private let updateUndoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private let updateRedoButtonIsEnabledStateSubject = PassthroughSubject<Bool, Never>()

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        localRepository: LocalRepository = DocumentsLocalRepository()
    ) {
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
                guard let `self` else { return }
                self.resetAllInputParameters()

                // Update the thumbnail when the layerView is visible
                if self.isLayerViewVisible {
                    self.canvasView?.commandBuffer?.addCompletedHandler { [weak self] _ in
                        DispatchQueue.main.async { [weak self] in
                            guard let `self` else { return }
                            self.textureLayers.updateThumbnail(index: self.textureLayers.index)
                        }
                    }
                }
            }
            .store(in: &cancellables)

        drawingTool.drawingToolPublisher
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush:
                    self.drawingTextureSet = self.drawingBrushTextureSet
                case .eraser:
                    self.drawingTextureSet = self.drawingEraserTextureSet
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

        drawingTool.backgroundColorPublisher
            .sink { [weak self] color in
                self?.textureLayers.backgroundColor = color
            }
            .store(in: &cancellables)

        textureLayers.updateCanvasPublisher
            .sink { [weak self] allLayerUpdates in
                self?.updateCanvasWithTextureLayers(allLayerUpdates: allLayerUpdates)
            }
            .store(in: &cancellables)
    }

    func initCanvas(size: CGSize) {
        textureLayers.initLayers(size: size)

        updateTextures(size: size)
    }

    func initCanvas(model: CanvasModel) {
        textureLayers.initLayers(
            layers: model.layers,
            layerIndex: model.layerIndex
        )

        projectName = model.projectName

        drawingTool.setBrushDiameter(model.brushDiameter)
        drawingTool.setEraserDiameter(model.eraserDiameter)
        drawingTool.setDrawingTool(.init(rawValue: model.drawingTool))

        updateTextures(size: model.textureSize)
    }

    private func updateTextures(size: CGSize) {
        drawingBrushTextureSet.initTextures(size)
        drawingEraserTextureSet.initTextures(size)

        currentTexture = MTLTextureCreator.makeTexture(size: size, with: device)
        canvasTexture = MTLTextureCreator.makeTexture(size: size, with: device)

        updateCanvasWithTextureLayers(allLayerUpdates: true)
    }

}

extension CanvasViewModel {
    func onViewDidLoad(
        canvasView: CanvasViewProtocol,
        textureSize: CGSize? = nil
    ) {
        self.canvasView = canvasView

        if let textureSize {
            initCanvas(size: textureSize)
        }
    }

    func onViewDidAppear(
        _ drawableTextureSize: CGSize
    ) {
        assert(self.canvasView != nil, "var canvasView is nil.")

        guard let canvasView else { return }

        // Since `func onUpdateRenderTexture` is not called at app launch on iPhone,
        // initialize the canvas here.
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(size: textureSize)
        }

        updateCanvasWithTextureLayers(allLayerUpdates: true)
    }

    func onUpdateRenderTexture() {
        guard let canvasView else { return }

        // Initialize the canvas here if `canvasTexture` is nil
        if canvasTexture == nil, let textureSize = canvasView.renderTexture?.size {
            initCanvas(size: textureSize)
        }

        // Redraws the canvas when the device rotates and the canvas size changes.
        updateCanvasWithTextureLayers(allLayerUpdates: true)
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
        case .drawing: drawFingerCurveOnCanvas()
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
        drawPencilCurveOnCanvas(actualTouches: actualTouches, view: view)
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {}
    func didTapRedoButton() {}

    func didTapLayerButton() {
        // During drawing, when `TextureLayerView` is hidden, the thumbnail is not created,
        // so update the thumbnail when `TextureLayerView` becomes visible.
        textureLayers.updateThumbnail(index: textureLayers.index)

        // Toggle the visibility of `TextureLayerView`
        requestShowingLayerViewSubject.send(!requestShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton() {
        transformer.setMatrix(.identity)
        updateCanvas()
    }

    func didTapNewCanvasButton() {
        guard
            let size = canvasTexture?.size
        else { return }

        projectName = Calendar.currentDate
        transformer.setMatrix(.identity)
        initCanvas(size: size)
    }

    func didTapLoadButton(filePath: String) {
        loadFile(from: filePath)
    }
    func didTapSaveButton() {
        guard let canvasTexture else { return }
        saveFile(canvasTexture: canvasTexture)
    }

    // MARK: Layers
    func didTapLayer(layer: TextureLayer) {
        textureLayers.selectTextureLayer(layer: layer)
    }
    func didTapAddLayerButton() {
        textureLayers.addTextureLayer(textureSize: canvasTexture?.size ?? .zero)
    }
    func didTapRemoveLayerButton() {
        textureLayers.removeTextureLayer()
    }
    func didMoveLayers(
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        textureLayers.moveTextureLayer(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    func didTapLayerVisibility(
        layer: TextureLayer,
        isVisible: Bool
    ) {
        textureLayers.changeVisibility(layer: layer, isVisible: isVisible)
    }
    func didStartChangingLayerAlpha(layer: TextureLayer) {}
    func didChangeLayerAlpha(
        layer: TextureLayer,
        value: Int
    ) {
        textureLayers.changeAlpha(layer: layer, alpha: value)
    }
    func didFinishChangingLayerAlpha(layer: TextureLayer) {}

    func didEditLayerTitle(
        layer: TextureLayer,
        title: String
    ) {
        textureLayers.changeTitle(layer: layer, title: title)
    }

}

extension CanvasViewModel {

    // Since the pencil takes priority, even if `drawingCurvePoints` contains an instance,
    // it will be overwritten when touchBegan occurs.
    private func isPencilDrawingCurvePointsInstanceCreated(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    // If `drawingCurvePoints` is nil, an instance of `FingerDrawingCurvePoints` will be set.
    private func isFingerDrawingCurvePointsInstanceCreated() -> Bool {
        drawingCurveIterator == nil
    }

    private func drawPencilCurveOnCanvas(actualTouches: Set<UITouch>, view: UIView) {
        if isPencilDrawingCurvePointsInstanceCreated(actualTouches: actualTouches) {
            drawingCurveIterator = PencilDrawingCurveIterator()
        }

        pencilScreenStrokeData.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        drawCurveOnCanvas(pencilScreenStrokeData.latestActualTouchPoints)
    }

    private func drawFingerCurveOnCanvas() {
        if isFingerDrawingCurvePointsInstanceCreated() {
            drawingCurveIterator = FingerDrawingCurvePoints()
        }

        fingerScreenStrokeData.setActiveDictionaryKeyIfNil()

        drawCurveOnCanvas(fingerScreenStrokeData.latestTouchPoints)
    }

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard
            let textureSize = canvasTexture?.size,
            let drawableSize = canvasView?.renderTexture?.size
        else { return }

        drawingCurveIterator?.appendToIterator(
            points: screenTouchPoints.map {
                .init(
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: textureSize,
                    drawableSize: drawableSize,
                    frameSize: frameSize,
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
        transformer.initTransformingIfNeeded(
            fingerScreenStrokeData.touchArrayDictionary
        )

        if fingerScreenStrokeData.isAllFingersOnScreen {
            transformer.transformCanvas(
                screenCenter: .init(
                    x: frameSize.width * 0.5,
                    y: frameSize.height * 0.5
                ),
                fingerScreenStrokeData.touchArrayDictionary
            )
        } else {
            transformer.finishTransforming()
        }

        updateCanvas()
    }

}

extension CanvasViewModel {

    private func updateCanvasWithTextureLayers(allLayerUpdates: Bool = false) {
        guard
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        textureLayers.mergeAllTextures(
            allLayerUpdates: allLayerUpdates,
            into: canvasTexture,
            with: commandBuffer
        )

        updateCanvas()
    }

    private func updateCanvasWithDrawing() {
        guard
            let drawingCurveIterator,
            let currentTexture,
            let selectedTexture = textureLayers.selectedLayer?.texture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        drawingTextureSet?.drawCurvePoints(
            drawingCurveIterator: drawingCurveIterator,
            withBackgroundTexture: selectedTexture,
            withBackgroundColor: .clear,
            on: currentTexture,
            with: commandBuffer
        )

        textureLayers.mergeAllTextures(
            usingCurrentTexture: currentTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        updateCanvas()
    }

    private func updateCanvas() {
        guard
            let renderTexture = canvasView?.renderTexture,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        MTLRenderer.shared.drawTexture(
            texture: canvasTexture,
            matrix: transformer.matrix,
            frameSize: frameSize,
            on: renderTexture,
            device: device,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

}

extension CanvasViewModel {

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerScreenStrokeData.reset()
        pencilScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()
    }

    private func cancelFingerDrawing() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearDrawingTextures(with: commandBuffer)
        commandBuffer.commit()

        fingerScreenStrokeData.reset()

        drawingCurveIterator = nil
        transformer.resetMatrix()

        canvasView?.resetCommandBuffer()
        updateCanvas()
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
            case .failure(let error): self?.requestShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: { [weak self] response in
            self?.refreshCanvasSubject.send(response)
        })
        .store(in: &cancellables)
    }

    private func saveFile(canvasTexture: MTLTexture) {
        localRepository?.saveDataToDocuments(
            renderTexture: canvasTexture,
            textureLayers: textureLayers,
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
