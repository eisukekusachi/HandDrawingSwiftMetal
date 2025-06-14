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

    /// A publisher that emits a value when the canvas setup is completed
    var canvasSetupCompletedPublisher: AnyPublisher<Void, Never> {
        canvasSetupCompletedSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when showing the activity indicator is needed
    var activityIndicatorShowRequestedPublisher: AnyPublisher<Bool, Never> {
        activityIndicatorShowRequestedSubject.eraseToAnyPublisher()
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

    /// A publisher that emits when the canvas view controller setup is needed
    var canvasViewControllerSetupPublisher: AnyPublisher<CanvasViewControllerConfiguration, Never> {
        canvasViewControllerSetupSubject.eraseToAnyPublisher()
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

    /// A rendering target
    private var canvasView: CanvasViewProtocol?

    /// Maintains the state of the canvas
    private let canvasState: CanvasState = .init(
        CanvasConfiguration()
    )

    /// It persists the canvas state to disk using `CoreData` when `textureRepository` is `DocumentsDirectoryTextureRepository`
    private var canvasStateStorage: CanvasStateStorage?

    /// A class for handling finger input values
    private let fingerScreenStrokeData = FingerScreenStrokeData()
    /// A class for handling Apple Pencil inputs
    private let pencilScreenStrokeData = PencilScreenStrokeData()

    /// An iterator that manages a single curve being drawn in real time
    private var singleCurveIterator: SingleCurveIterator?

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

    private let canvasSetupCompletedSubject = PassthroughSubject<Void, Never>()

    private let activityIndicatorShowRequestedSubject: PassthroughSubject<Bool, Never> = .init()

    private let needsShowingAlertSubject = PassthroughSubject<String, Never>()

    private let needsShowingToastSubject = PassthroughSubject<ToastModel, Never>()

    private let needsShowingLayerViewSubject = CurrentValueSubject<Bool, Never>(false)

    private var canvasViewControllerSetupSubject: PassthroughSubject<CanvasViewControllerConfiguration, Never> = .init()

    private let needsCanvasRefreshSubject = PassthroughSubject<CanvasConfiguration, Never>()

    private let needsUndoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private let needsRedoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private var localRepository: LocalRepository!

    private var textureLayerRepository: TextureLayerRepository!

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        textureLayerRepository: TextureLayerRepository,
        localRepository: LocalRepository = DocumentsLocalSingletonRepository.shared
    ) {
        self.textureLayerRepository = textureLayerRepository
        self.renderer.setTextureRepository(textureLayerRepository)

        self.localRepository = localRepository

        // If `TextureLayerDocumentsDirectorySingletonRepository` is used, `CanvasStateStorage` is enabled
        if textureLayerRepository is TextureLayerDocumentsDirectorySingletonRepository {
            canvasStateStorage = CanvasStateStorage()
            canvasStateStorage?.setupStorage(canvasState)
        }

        bindData()
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.canvasDrawingPublisher
            .sink { [weak self] in
                guard
                    let singleCurveIterator = self?.singleCurveIterator,
                    let texture = self?.renderer.selectedTexture,
                    let selectedLayerId = self?.canvasState.selectedLayer?.id,
                    let commandBuffer = self?.canvasView?.commandBuffer
                else { return }

                self?.drawingTextureSet?.updateRealTimeDrawingTexture(
                    singleCurveIterator: singleCurveIterator,
                    baseTexture: texture,
                    with: commandBuffer
                ) { [weak self] in
                    commandBuffer.addCompletedHandler { [weak self] _ in
                        self?.updateLocalRepositoryTexture(texture: texture, for: selectedLayerId)
                    }
                }
            }
            .store(in: &cancellables)

        Publishers.Merge(
            drawingBrushTextureSet.realtimeDrawingTexturePublisher,
            drawingEraserTextureSet.realtimeDrawingTexturePublisher
        )
            .sink { [weak self] texture in
                self?.updateCanvasView(realtimeDrawingTexture: texture)
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

        // Update the canvas
        canvasState.canvasUpdateSubject
            .sink { [weak self] in
                self?.updateCanvasView()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        canvasState.fullCanvasUpdateSubject
            .sink { [weak self] in
                guard
                    let `self`,
                    let commandBuffer = canvasView?.commandBuffer
                else { return }

                self.renderer.updateDrawingTextures(
                    canvasState: self.canvasState,
                    with: commandBuffer
                ) { [weak self] in
                    self?.updateCanvasView()
                }
            }
            .store(in: &cancellables)

        canvasStateStorage?.errorDialogSubject
            .sink { [weak self] error in
                self?.needsShowingAlertSubject.send(error.localizedDescription)
            }
            .store(in: &cancellables)

        // Initialize the texture storage using the specified texture size.
        textureLayerRepository.storageInitializationWithNewTexturePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                guard let drawableSize = self?.canvasView?.renderTexture?.size else { return }
                self?.textureLayerRepository.initializeStorageWithNewTexture(
                    configuration.textureSize ?? drawableSize
                )
            }
            .store(in: &cancellables)

        // Complete the canvas setup after the texture storage is initialized.
        textureLayerRepository.storageInitializationCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                self?.completeCanvasSetup(configuration)
            }
            .store(in: &cancellables)

        transformer.matrixPublisher
            .assign(to: \.matrix, on: renderer)
            .store(in: &cancellables)
    }

}

extension CanvasViewModel {

    func initializeCanvas(using configuration: CanvasConfiguration) {
        textureLayerRepository.initializeStorage(from: configuration)
    }

    private func completeCanvasSetup(_ configuration: CanvasConfiguration) {
        guard
            let textureSize = configuration.textureSize,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        canvasState.setData(configuration)

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            with: commandBuffer
        ) { [weak self] in
            self?.updateCanvasView()
        }

        textureLayerRepository
            .updateAllThumbnails(textureSize: textureSize)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished: break
                case .failure(let error): Logger.standard.error("Failed to update all thumbnails: \(error)")
                }
                self?.canvasSetupCompletedSubject.send(())
                self?.activityIndicatorShowRequestedSubject.send(false)
            }, receiveValue: {})
            .store(in: &cancellables)
    }

}

extension CanvasViewModel {

    func onViewDidLoad(
        canvasView: CanvasViewProtocol
    ) {
        self.canvasView = canvasView

        canvasViewControllerSetupSubject.send(
            .init(
                canvasState: canvasState,
                textureLayerRepository: textureLayerRepository
            )
        )
    }

    func onViewWillAppear() {
        activityIndicatorShowRequestedSubject.send(true)
    }

    func onViewDidAppear(
        configuration: CanvasConfiguration,
        drawableTextureSize: CGSize
    ) {
        if !textureLayerRepository.isInitialized {
            let existingValue = canvasStateStorage?.coreDataConfiguration
            let defaultValue = configuration.createConfigurationWithValidTextureSize(drawableTextureSize)
            initializeCanvas(using: existingValue ?? defaultValue)
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
            if shouldCreateFingerSingleCurveIteratorInstance() {
                singleCurveIterator = FingerSingleCurveIterator()
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
        if shouldCreatePencilSingleCurveIteratorInstance(actualTouches: actualTouches) {
            singleCurveIterator = PencilSingleCurveIterator()
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
        needsShowingLayerViewSubject.send(!needsShowingLayerViewSubject.value)
    }

    func didTapResetTransformButton() {
        guard let commandBuffer = canvasView?.commandBuffer else { return }
        transformer.setMatrix(.identity)
        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

    func didTapNewCanvasButton() {
        transformer.setMatrix(.identity)
        initializeCanvas(
            using: CanvasConfiguration().createConfigurationWithValidTextureSize(canvasState.textureSize)
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
            let drawableSize = canvasView?.renderTexture?.size,
            let diameter = canvasState.drawingToolDiameter
        else { return }

        singleCurveIterator?.append(
            points: screenTouchPoints.map {
                .init(
                    matrix: transformer.matrix.inverted(flipY: true),
                    touchPoint: $0,
                    textureSize: canvasState.textureSize,
                    drawableSize: drawableSize,
                    frameSize: renderer.frameSize,
                    diameter: CGFloat(diameter)
                )
            },
            touchPhase: screenTouchPoints.lastTouchPhase
        )

        drawingDisplayLink.run(singleCurveIterator?.isCurrentlyDrawing ?? false)
    }

    private func transformCanvas() {
        guard let commandBuffer = canvasView?.commandBuffer else { return }

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

        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

}

extension CanvasViewModel {
    // Even if `singleCurveIterator` already exists, it will be replaced with a new `PencilSingleCurveIterator`
    // whenever a touch with `.began` phase is detected, since pencil input takes precedence.
    private func shouldCreatePencilSingleCurveIteratorInstance(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    // Set a new `FingerSingleCurveIterator` if `singleCurveIterator` is nil.
    private func shouldCreateFingerSingleCurveIteratorInstance() -> Bool {
        singleCurveIterator == nil
    }

    private func cancelFingerDrawing() {
        guard let commandBuffer = canvasView?.commandBuffer else { return }

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerScreenStrokeData.reset()

        singleCurveIterator = nil
        transformer.resetMatrix()

        canvasView?.resetCommandBuffer()

        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

    private func updateLocalRepositoryTexture(texture: MTLTexture, for selectedTextureId: UUID) {
        textureLayerRepository.updateTexture(
            texture: texture,
            for: selectedTextureId
        )
        .sink(
            receiveCompletion: { [weak self] result in
                switch result {
                case .finished: break
                case .failure(let error):
                    Logger.standard.error("Failed to complete the drawing process: \(error)")
                }
                self?.resetAllInputParameters()
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerScreenStrokeData.reset()
        pencilScreenStrokeData.reset()

        singleCurveIterator = nil
        transformer.resetMatrix()
    }

    func updateCanvasView(realtimeDrawingTexture: MTLTexture? = nil) {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        renderer.updateCanvasView(
            canvasView,
            realtimeDrawingTexture: realtimeDrawingTexture,
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

}

extension CanvasViewModel {

    private func loadFile(from filePath: String) {
        localRepository.loadDataFromDocuments(
            sourceURL: URL.documents.appendingPathComponent(filePath),
            textureRepository: textureLayerRepository
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorShowRequestedSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorShowRequestedSubject.send(false) }
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
            textureRepository: textureLayerRepository,
            to: URL.zipFileURL(projectName: canvasState.projectName)
        )
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorShowRequestedSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorShowRequestedSubject.send(false) }
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
