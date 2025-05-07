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

    var frameSize: CGSize = .zero {
        didSet {
            renderer.frameSize = frameSize
        }
    }

    /// A publisher that emits when the canvas setup is needed
    var needsCanvasSetupPublisher: AnyPublisher<CanvasState, Never> {
        needsCanvasSetupSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when showing the activity indicator is needed
    var needsShowingActivityIndicatorPublisher: AnyPublisher<Bool, Never> {
        needsShowingActivityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when showing an alert is needed
    var needsShowingAlertPublisher: AnyPublisher<String, Never> {
        needsShowingAlertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when showing a toast is needed
    var needsShowingToastPublisher: AnyPublisher<ToastModel, Never> {
        needsShowingToastSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when showing the layer view is needed
    var needsShowingLayerViewPublisher: AnyPublisher<Bool, Never> {
        needsShowingLayerViewSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when refreshing the canvas is needed
    var needsCanvasRefreshPublisher: AnyPublisher<CanvasConfiguration, Never> {
        needsCanvasRefreshSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when updating the undo button state is needed.
    var needsUndoButtonStateUpdatePublisher: AnyPublisher<Bool, Never> {
        needsUndoButtonStateUpdateSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when updating the redo button state is needed
    var needsRedoButtonStateUpdatePublisher: AnyPublisher<Bool, Never> {
        needsRedoButtonStateUpdateSubject.eraseToAnyPublisher()
    }

    private let canvasState: CanvasState = .init(
        CanvasConfiguration()
    )

    private var canvasStateStorage: CanvasStateStorage?

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

    private var needsCanvasSetupSubject: PassthroughSubject<CanvasState, Never> = .init()

    private let needsShowingActivityIndicatorSubject = CurrentValueSubject<Bool, Never>(false)

    private let needsShowingAlertSubject = PassthroughSubject<String, Never>()

    private let needsShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let needsShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private let needsCanvasRefreshSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsUndoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private let needsRedoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private var localRepository: LocalRepository!

    private var textureRepository: TextureRepository!

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        textureRepository: TextureRepository,
        localRepository: LocalRepository = DocumentsLocalSingletonRepository.shared
    ) {
        self.textureRepository = textureRepository
        self.localRepository = localRepository

        // If `DocumentsFolderTextureRepository` is used, `CanvasStateStorage` is enabled
        if textureRepository is DocumentsFolderTextureRepository {
            canvasStateStorage = CanvasStateStorage()
            canvasStateStorage?.setupStorage(canvasState)
        }

        bindData()
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.canvasDrawingPublisher
            .sink { [weak self] in
                self?.updateCanvasWithDrawing()
            }
            .store(in: &cancellables)

        // The canvas is updated when drawing ends
        Publishers.Merge(
            drawingBrushTextureSet.canvasDrawFinishedPublisher,
            drawingEraserTextureSet.canvasDrawFinishedPublisher
        )
        .sink { [weak self] in
            self?.completeCanvasUpdateWithDrawing()
        }
        .store(in: &cancellables)

        // Update drawingTextureSet when the tool is switched
        canvasState.drawingToolState.$drawingTool
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush: self.drawingTextureSet = self.drawingBrushTextureSet
                case .eraser: self.drawingTextureSet = self.drawingEraserTextureSet
                }
            }
            .store(in: &cancellables)

        // Update the color of drawingBrushTextureSet when the brush color changes
        canvasState.drawingToolState.brush.$color
            .sink { [weak self] color in
                self?.drawingBrushTextureSet.setBlushColor(color)
            }
            .store(in: &cancellables)

        // Update the alpha of drawingEraserTextureSet when the eraser alpha changes
        canvasState.drawingToolState.eraser.$alpha
            .sink { [weak self] alpha in
                self?.drawingEraserTextureSet.setEraserAlpha(alpha)
            }
            .store(in: &cancellables)

        // Restore the canvas using CanvasConfiguration
        textureRepository.canvasInitializationUsingConfigurationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                self?.completeCanvasSetup(configuration)
            }
            .store(in: &cancellables)

        // Initialize the canvas using the textureSize
        textureRepository.storageInitializationWithNewTexturePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                guard let drawableSize = self?.renderer.renderTextureSize else { return }
                self?.textureRepository.initializeStorageWithNewTexture(
                    configuration.getTextureSize(drawableSize: drawableSize)
                )
            }
            .store(in: &cancellables)

        // Update the canvas after updating the layers
        textureRepository.needsCanvasUpdateAfterTextureLayersUpdatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let `self` else { return }
                self.renderer.updateCanvasAfterUpdatingAllTextures(
                    canvasState: self.canvasState,
                    commandBuffer: self.renderer.commandBuffer
                )
            }
            .store(in: &cancellables)

        // Update the canvas
        textureRepository.needsCanvasUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateCanvas()
            }
            .store(in: &cancellables)

        canvasState.$backgroundColor
            .assign(to: \.backgroundColor, on: renderer)
            .store(in: &cancellables)

        transformer.matrixPublisher
            .assign(to: \.matrix, on: renderer)
            .store(in: &cancellables)
    }

}

extension CanvasViewModel {

    func initCanvas(using configuration: CanvasConfiguration) {
        guard let drawableSize = renderer.renderTextureSize else { return }
        textureRepository.resolveCanvasView(from: configuration, drawableSize: drawableSize)
    }

    private func completeCanvasSetup(_ configuration: CanvasConfiguration) {
        guard
            let commandBuffer = renderer.commandBuffer,
            let textureSize = configuration.textureSize
        else { return }

        canvasState.setData(configuration)

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)
        renderer.updateCanvasAfterUpdatingAllTextures(
            canvasState: canvasState,
            commandBuffer: commandBuffer
        )
    }

}

extension CanvasViewModel {

    func onViewDidLoad(
        canvasView: CanvasViewProtocol
    ) {
        renderer.setCanvas(canvasView)

        needsCanvasSetupSubject.send(canvasState)
    }

    func onViewDidAppear(
        configuration: CanvasConfiguration,
        drawableTextureSize: CGSize
    ) {
        if !renderer.hasTextureBeenInitialized {
            initCanvas(using: canvasStateStorage?.configuration ?? configuration)
        }
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

    func updateCanvas() {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let commandBuffer = renderer.commandBuffer
        else { return }

        renderer.updateCanvas(
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {}
    func didTapRedoButton() {}

    func didTapLayerButton() {
        // Toggle the visibility of `TextureLayerView`
        needsShowingLayerViewSubject.send(!needsShowingLayerViewSubject.value)
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

}

extension CanvasViewModel {

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard
            let drawableSize = renderer.renderTextureSize,
            let diameter = canvasState.drawingToolDiameter
        else { return }

        drawingCurveIterator?.append(
            points: screenTouchPoints.map {
                .init(
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: renderer.textureSize,
                    drawableSize: drawableSize,
                    frameSize: renderer.frameSize,
                    diameter: CGFloat(diameter)
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

    private func updateCanvasWithDrawing() {
        guard
            let drawingCurveIterator,
            let selectedLayer = canvasState.selectedLayer,
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
                    let selectedTextureId = self?.canvasState.selectedLayer?.id
                else { return }

                self?.renderer.renderTextureToLayerInRepository(
                    texture: selectedTexture,
                    targetTextureId: selectedTextureId
                ) { [weak self] texture in
                    self?.textureRepository?.setThumbnail(
                        texture: selectedTexture,
                        for: selectedTextureId
                    )
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
            receiveSubscription: { [weak self] _ in self?.needsShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.needsShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.needsShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.needsShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: { [weak self] configuration in
            self?.needsCanvasRefreshSubject.send(configuration)
        })
        .store(in: &cancellables)
    }

    private func saveFile(canvasTexture: MTLTexture) {
        localRepository.saveDataToDocuments(
            renderTexture: canvasTexture,
            canvasState: canvasState,
            textureRepository: textureRepository,
            to: URL.getZipFileURL(projectName: canvasState.projectName)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.needsShowingActivityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.needsShowingActivityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.needsShowingToastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.needsShowingAlertSubject.send(error.localizedDescription)
            }
        }, receiveValue: {})
        .store(in: &cancellables)
    }

}
