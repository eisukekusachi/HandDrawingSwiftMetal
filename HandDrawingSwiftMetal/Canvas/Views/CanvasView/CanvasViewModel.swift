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

    static var fileSuffix: String {
        "zip"
    }

    var frameSize: CGSize = .zero {
        didSet {
            renderer.frameSize = frameSize
        }
    }

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicatorShowRequestPublisher: AnyPublisher<Bool, Never> {
        activityIndicatorShowRequestSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    var toastShowRequestPublisher: AnyPublisher<ToastModel, Never> {
        toastShowRequestSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the layer view
    var layerViewShowRequestPublisher: AnyPublisher<Bool, Never> {
        layerViewShowRequestSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `CanvasViewControllerConfiguration`  when subviews need to be configured
    var viewConfigureRequestPublisher: AnyPublisher<CanvasViewControllerConfiguration, Never> {
        viewConfigureRequestSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `Void` when the canvas view setup is completed
    var canvasViewSetupCompletedPublisher: AnyPublisher<Void, Never> {
        canvasViewSetupCompletedSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when updating the undo button state is needed.
    var needsUndoButtonStateUpdatePublisher: AnyPublisher<Bool, Never> {
        needsUndoButtonStateUpdateSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits when updating the redo button state is needed
    var needsRedoButtonStateUpdatePublisher: AnyPublisher<Bool, Never> {
        needsRedoButtonStateUpdateSubject.eraseToAnyPublisher()
    }

    var canvasViewControllerUndoButtonsDisplayPublisher: AnyPublisher<Bool, Never> {
        canvasViewControllerUndoButtonsDisplaySubject.eraseToAnyPublisher()
    }

    /// A rendering target
    private var canvasView: CanvasViewProtocol?

    /// Maintains the state of the canvas
    private let canvasState: CanvasState = .init(
        CanvasConfiguration()
    )
    /// It persists the canvas state to disk using `CoreData` when `textureLayerRepository` is `TextureLayerDocumentsDirectorySingletonRepository`
    private var canvasStateStorage: CanvasStateStorage?

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// An iterator that manages a single curve being drawn in realtime
    private var singleCurveIterator: SingleCurveIterator?

    /// A texture set for realtime drawing
    private var drawingTextureSet: CanvasDrawingTextureSet?
    /// A brush texture set for realtime drawing
    private let drawingBrushTextureSet = CanvasDrawingBrushTextureSet()
    /// An eraser texture set for realtime drawing
    private let drawingEraserTextureSet = CanvasDrawingEraserTextureSet()

    /// A display link for realtime drawing
    private var drawingDisplayLink = CanvasDrawingDisplayLink()

    private var renderer = CanvasRenderer()

    private let transformer = CanvasTransformer()

    /// Manages input from pen and finger
    private let inputDevice = CanvasInputDeviceStatus()

    /// Manages on-screen gestures such as drag and pinch
    private let screenTouchGesture = CanvasScreenTouchGestureStatus()

    private let activityIndicatorShowRequestSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<Error, Never>()

    private let toastShowRequestSubject = PassthroughSubject<ToastModel, Never>()

    private let layerViewShowRequestSubject = CurrentValueSubject<Bool, Never>(false)

    private var viewConfigureRequestSubject: PassthroughSubject<CanvasViewControllerConfiguration, Never> = .init()

    private let canvasViewSetupCompletedSubject = PassthroughSubject<Void, Never>()

    private let needsUndoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private let needsRedoButtonStateUpdateSubject = PassthroughSubject<Bool, Never>()

    private var canvasViewControllerUndoButtonsDisplaySubject: PassthroughSubject<Bool, Never> = .init()

    /// A repository for loading and saving local files
    private var localFileRepository: LocalFileRepository!

    /// A repository for managing texture layers
    private var textureLayerRepository: TextureLayerRepository!

    private var undoStack: UndoStack? = nil

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository?,
        localFileRepository: LocalFileRepository = LocalFileSingletonRepository.shared
    ) {
        self.textureLayerRepository = textureLayerRepository
        self.renderer.setTextureRepository(textureLayerRepository)

        self.localFileRepository = localFileRepository

        // If `TextureLayerDocumentsDirectorySingletonRepository` is used, `CanvasStateStorage` is enabled
        if textureLayerRepository is TextureLayerDocumentsDirectorySingletonRepository {
            canvasStateStorage = CanvasStateStorage()
            canvasStateStorage?.setupStorage(canvasState)
        }

        // If `undoTextureRepository` is used, undo functionality is enabled
        if let undoTextureRepository {
            undoStack = .init(
                canvasState: canvasState,
                textureLayerRepository: textureLayerRepository,
                undoTextureRepository: undoTextureRepository
            )
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
                    with: commandBuffer,
                    onDrawingCompleted: {
                        commandBuffer.addCompletedHandler { [weak self] _ in
                            self?.completeDrawingProcess(texture: texture, for: selectedLayerId)
                        }
                    }
                )
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
                self?.updateCanvasByMergingAllLayers()
            }
            .store(in: &cancellables)

        canvasStateStorage?.errorDialogSubject
            .sink { [weak self] error in
                self?.alertSubject.send(error)
            }
            .store(in: &cancellables)

        transformer.matrixPublisher
            .assign(to: \.matrix, on: renderer)
            .store(in: &cancellables)

        // Undo
        undoStack?.undoButtonStateUpdateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.needsUndoButtonStateUpdateSubject.send(state)
            }
            .store(in: &cancellables)

        undoStack?.redoButtonStateUpdateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.needsRedoButtonStateUpdateSubject.send(state)
            }
            .store(in: &cancellables)
    }

}

extension CanvasViewModel {

    func initialize(using configuration: CanvasConfiguration) {
        textureLayerRepository.initializeStorage(configuration: configuration)
            .handleEvents(
                receiveSubscription: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(true) },
                receiveCompletion: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(false) }
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished: break
                    case .failure(let error): Logger.standard.error("Initialization failed. Please set an appropriate texture size and restart the application: \(error)")
                    }
                },
                receiveValue: { [weak self] result in
                    Task { @MainActor in
                        self?.completeInitialization(result)
                    }
                }
            )
            .store(in: &cancellables)
    }

    @MainActor private func completeInitialization(_ configuration: CanvasConfiguration) {
        guard
            let textureSize = configuration.textureSize,
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        canvasState.setData(configuration)

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)

        undoStack?.initialize(textureSize)

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            with: commandBuffer
        ) { [weak self] in
            self?.updateCanvasView()
        }

        canvasViewSetupCompletedSubject.send(())
        activityIndicatorShowRequestSubject.send(false)
    }
}

extension CanvasViewModel {

    func onViewDidLoad(
        canvasView: CanvasViewProtocol
    ) {
        self.canvasView = canvasView

        viewConfigureRequestSubject.send(
            .init(
                canvasState: canvasState,
                textureLayerRepository: textureLayerRepository,
                undoStack: undoStack
            )
        )

        if undoStack != nil {
            canvasViewControllerUndoButtonsDisplaySubject.send(true)
        }
    }

    func onViewWillAppear() {
        activityIndicatorShowRequestSubject.send(true)
    }

    func onViewDidAppear(
        configuration: CanvasConfiguration,
        drawableTextureSize: CGSize
    ) {
        if !textureLayerRepository.isInitialized {
            initialize(
                using: canvasStateStorage?.coreDataConfiguration ?? configuration.resolvedTextureSize(drawableTextureSize)
            )
        }
    }

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        guard inputDevice.update(.finger) != .pencil else { return }

        fingerStroke.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch screenTouchGesture.update(fingerStroke.touchArrayDictionary) {
        case .drawing:
            if FingerSingleCurveIterator.shouldCreateInstance(singleCurveIterator: singleCurveIterator) {
                singleCurveIterator = FingerSingleCurveIterator()
                undoStack?.setDrawingUndoObject()
            }

            fingerStroke.setActiveDictionaryKeyIfNil()

            drawCurveOnCanvas(fingerStroke.latestTouchPoints)

        case .transforming: transformCanvas()
        default: break
        }

        fingerStroke.removeEndedTouchArrayFromDictionary()

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

        pencilStroke.setLatestEstimatedTouchPoint(
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
        if PencilSingleCurveIterator.shouldCreateInstance(actualTouches: actualTouches) {
            singleCurveIterator = PencilSingleCurveIterator()
            undoStack?.setDrawingUndoObject()
        }

        pencilStroke.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        drawCurveOnCanvas(pencilStroke.latestActualTouchPoints)
    }

}

extension CanvasViewModel {
    // MARK: Toolbar
    func didTapUndoButton() {
        undoStack?.undo()
    }
    func didTapRedoButton() {
        undoStack?.redo()
    }

    func didTapLayerButton() {
        // Toggle the visibility of `TextureLayerView`
        layerViewShowRequestSubject.send(!layerViewShowRequestSubject.value)
    }

    func didTapResetTransformButton() {
        guard let commandBuffer = canvasView?.commandBuffer else { return }
        transformer.setMatrix(.identity)
        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

    func didTapNewCanvasButton() {
        transformer.setMatrix(.identity)
        initialize(
            using: CanvasConfiguration(textureSize: canvasState.textureSize)
        )
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
            fingerStroke.touchArrayDictionary
        )

        if fingerStroke.isAllFingersOnScreen {
            transformer.transformCanvas(
                screenCenter: .init(
                    x: renderer.frameSize.width * 0.5,
                    y: renderer.frameSize.height * 0.5
                ),
                fingerStroke.touchArrayDictionary
            )
        } else {
            transformer.finishTransforming()
        }

        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

}

extension CanvasViewModel {

    private func cancelFingerDrawing() {
        guard let commandBuffer = canvasView?.commandBuffer else { return }

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerStroke.reset()

        singleCurveIterator = nil
        transformer.resetMatrix()

        canvasView?.resetCommandBuffer()

        renderer.updateCanvasView(canvasView, with: commandBuffer)
    }

    private func completeDrawingProcess(texture: MTLTexture, for selectedTextureId: UUID) {
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
            receiveValue: { [weak self] result in
                if let canvasState = self?.canvasState {
                    self?.undoStack?.pushUndoDrawingObject(
                        canvasState: canvasState,
                        texture: result.texture
                    )
                }
            }
        )
        .store(in: &cancellables)
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        screenTouchGesture.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        singleCurveIterator = nil
        transformer.resetMatrix()
    }

    func updateCanvasByMergingAllLayers() {
        guard
            let commandBuffer = canvasView?.commandBuffer
        else { return }

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            with: commandBuffer
        ) { [weak self] in
            self?.updateCanvasView()
        }
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

    func loadFile(zipFileURL: URL) {
        do {
            try localFileRepository.createWorkingDirectory()
        }
        catch(let error) {
            alertSubject.send(error)
        }

        localFileRepository.unzipToWorkingDirectory(
            from: zipFileURL
        )
        .flatMap { workingDirectoryURL -> AnyPublisher<CanvasConfiguration, Error> in
            do {
                let entity: CanvasEntity = try .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(CanvasEntity.jsonFileName)
                )
                let configuration: CanvasConfiguration = .init(
                    projectName: zipFileURL.fileName,
                    entity: entity
                )
                return self.textureLayerRepository.restoreStorage(
                    from: workingDirectoryURL,
                    with: configuration
               )
           } catch(let error) {
               return Fail(error: error).eraseToAnyPublisher()
           }
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.toastShowRequestSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.alertSubject.send(error)
            }

            self?.localFileRepository.removeWorkingDirectory()

        }, receiveValue: { [weak self] configuration in
            Task { @MainActor in
                self?.completeInitialization(configuration)
            }
        })
        .store(in: &cancellables)
    }

    func saveFile() {
        guard
            let canvasTexture = renderer.canvasTexture,
            let thumbnail = canvasTexture.uiImage?.resizeWithAspectRatio(
                height: CanvasEntity.thumbnailLength,
                scale: 1.0
            )
        else { return }

        let zipFileURL = LocalFileRepository.fileURL(
            projectName: canvasState.projectName,
            suffix: CanvasViewModel.fileSuffix
        )
        let entity = CanvasEntity(
            thumbnailName: CanvasEntity.thumbnailName,
            canvasState: canvasState
        )

        do {
            try localFileRepository.createWorkingDirectory()
        }
        catch(let error) {
            alertSubject.send(error)
        }

        textureLayerRepository.copyTextures(
            uuids: canvasState.layers.map { $0.id }
        )
        .flatMap { [weak self] identifiedTextures -> AnyPublisher<Void, Error> in
            guard let self else {
                return Fail(
                    error: CanvasViewModelError.invalidValue("failed to unwrap")
                ).eraseToAnyPublisher()
            }

            return Publishers.CombineLatest(
                self.localFileRepository.saveToWorkingDirectory(
                    namedItem: .init(name: CanvasEntity.thumbnailName, item: thumbnail)
                ),
                self.localFileRepository.saveAllToWorkingDirectory(
                    namedItems: identifiedTextures.map {
                        .init(name: $0.uuid.uuidString, item: $0)
                    }
                )
            )
            .map { _, _ in () }
            .eraseToAnyPublisher()
        }
        .flatMap { [weak self] _ -> AnyPublisher<URL, Error> in
            self?.localFileRepository.saveToWorkingDirectory(
                namedItem: .init(
                    name: CanvasEntity.jsonFileName,
                    item: entity
                )
            ) ?? Fail(
                error: CanvasViewModelError.invalidValue("failed to unwrap")
            ).eraseToAnyPublisher()
        }
        .tryMap { [weak self] result in
            try self?.localFileRepository.zipWorkingDirectory(
                to: zipFileURL
            )
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorShowRequestSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.toastShowRequestSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.alertSubject.send(error)
            }

            self?.localFileRepository.removeWorkingDirectory()

        }, receiveValue: {})
        .store(in: &cancellables)
    }
}

enum CanvasViewModelError: Error {
    case invalidValue(String)
}
