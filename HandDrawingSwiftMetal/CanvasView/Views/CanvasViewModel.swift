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

    /// Maintains the state of the canvas
    let canvasState: CanvasState = .init(
        CanvasConfiguration()
    )

    static var fileSuffix: String {
        "zip"
    }

    var frameSize: CGSize = .zero {
        didSet {
            renderer.frameSize = frameSize
        }
    }

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    var toast: AnyPublisher<ToastModel, Never> {
        toastSubject.eraseToAnyPublisher()
    }

    var undoRedoButtonState: AnyPublisher<UndoRedoButtonState, Never> {
        undoRedoButtonStateSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `Void` when the canvas view setup is completed
    var canvasViewSetupCompleted: AnyPublisher<Void, Never> {
        canvasViewSetupCompletedSubject.eraseToAnyPublisher()
    }

    var textureLayerConfiguration: TextureLayerConfiguration {
        .init(
            canvasState: canvasState,
            textureLayerRepository: textureLayerRepository,
            undoStack: undoStack
        )
    }

    /// A rendering target
    private var displayView: CanvasDisplayable?

    /// It persists the canvas state to disk using `CoreData` when `textureLayerRepository` is `TextureLayerDocumentsDirectorySingletonRepository`
    private var canvasStateStorage: CanvasStateStorage?

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    /// A texture set for realtime drawing
    private var drawingTextureSet: DrawingTextureSet?
    /// A brush texture set for realtime drawing
    private let drawingBrushTextureSet = DrawingBrushTextureSet()
    /// An eraser texture set for realtime drawing
    private let drawingEraserTextureSet = DrawingEraserTextureSet()

    /// A display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    private var renderer = CanvasRenderer()

    private let transformer = CanvasTransformer()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceStatus()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGestureStatus = TouchGestureStatus()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<Error, Never>()

    private let toastSubject = PassthroughSubject<ToastModel, Never>()

    private let canvasViewSetupCompletedSubject = PassthroughSubject<Void, Never>()

    private var undoRedoButtonStateSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    /// A repository for loading and saving local files
    private var localFileRepository: LocalFileRepository!

    /// A repository for managing texture layers
    private var textureLayerRepository: TextureLayerRepository!

    private var undoStack: UndoStack? = nil

    private var cancellables = Set<AnyCancellable>()

    private let device = MTLCreateSystemDefaultDevice()!

    init() {
        bindData()
    }

    func initialize(
        textureLayerRepository: TextureLayerRepository,
        undoTextureRepository: TextureRepository?,
        localFileRepository: LocalFileRepository = LocalFileSingletonRepository.shared.repository,
        displayView: CanvasDisplayable,
        configuration: CanvasConfiguration,
        defaultTextureSize: CGSize
    ) {
        self.textureLayerRepository = textureLayerRepository

        self.renderer.initialize(
            configuration: configuration
        )

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

        self.displayView = displayView

        // Use the size from CoreData if available,
        // if not, use the size from the configuration,
        // otherwise, fall back to the default value
        initialize(
            configuration: canvasStateStorage?.coreDataConfiguration ?? configuration.resolvedTextureSize(defaultTextureSize)
        )
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.updatePublisher
            .sink { [weak self] in
                guard
                    let drawingCurve = self?.drawingCurve,
                    let texture = self?.renderer.selectedTexture,
                    let selectedLayerId = self?.canvasState.selectedLayer?.id,
                    let commandBuffer = self?.displayView?.commandBuffer
                else { return }

                self?.drawingTextureSet?.updateRealTimeDrawingTexture(
                    baseTexture: texture,
                    drawingCurve: drawingCurve,
                    with: commandBuffer,
                    onDrawing: { [weak self] resultTexture in
                        self?.updateCanvasView(realtimeDrawingTexture: resultTexture)
                    },
                    onDrawingCompleted: { resultTexture in
                        commandBuffer.addCompletedHandler { [weak self] _ in
                            self?.completeDrawing(texture: resultTexture, for: selectedLayerId)
                        }
                    }
                )
            }
            .store(in: &cancellables)

        // Update drawingTextureSet when the tool is switched
        canvasState.$drawingTool
            .sink { [weak self] tool in
                guard let `self` else { return }
                switch tool {
                case .brush: self.drawingTextureSet = self.drawingBrushTextureSet
                case .eraser: self.drawingTextureSet = self.drawingEraserTextureSet
                }
            }
            .store(in: &cancellables)

        // Update the color of drawingBrushTextureSet when the brush color changes
        canvasState.brush.$color
            .sink { [weak self] color in
                self?.drawingBrushTextureSet.setBrushColor(color)
            }
            .store(in: &cancellables)

        // Update the alpha of drawingEraserTextureSet when the eraser alpha changes
        canvasState.eraser.$alpha
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

        undoStack?.undoRedoButtonStateSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.undoRedoButtonStateSubject.send(state)
            }
            .store(in: &cancellables)
    }
}

extension CanvasViewModel {

    var currentTextureSize: CGSize {
        canvasState.textureSize
    }

    func initialize(configuration: CanvasConfiguration) {
        // Initialize the texture repository
        textureLayerRepository.initializeStorage(configuration: configuration)
            .handleEvents(
                receiveSubscription: { [weak self] _ in self?.activityIndicatorSubject.send(true) },
                receiveCompletion: { [weak self] _ in self?.activityIndicatorSubject.send(false) }
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
                        self?.setupCanvas(result)
                    }
                }
            )
            .store(in: &cancellables)
    }

    @MainActor private func setupCanvas(_ configuration: CanvasConfiguration) {
        guard
            let textureSize = configuration.textureSize,
            let commandBuffer = displayView?.commandBuffer
        else { return }

        canvasState.setData(configuration)

        drawingBrushTextureSet.initTextures(textureSize)
        drawingEraserTextureSet.initTextures(textureSize)

        renderer.initTextures(textureSize: textureSize)

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            textureLayerRepository: textureLayerRepository,
            with: commandBuffer
        ) { [weak self] in
            self?.updateCanvasView()
        }

        undoStack?.initialize(textureSize)

        canvasViewSetupCompletedSubject.send(())
        activityIndicatorSubject.send(false)
    }
}

extension CanvasViewModel {

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
        switch touchGestureStatus.update(fingerStroke.touchHistories) {
        case .drawing:
            if SmoothDrawingCurve.shouldCreateInstance(drawingCurve: drawingCurve) {
                drawingCurve = SmoothDrawingCurve()
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
        if DefaultDrawingCurve.shouldCreateInstance(actualTouches: actualTouches) {
            drawingCurve = DefaultDrawingCurve()
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

    func resetTransforming() {
        guard let commandBuffer = displayView?.commandBuffer else { return }
        transformer.setMatrix(.identity)
        renderer.updateCanvasView(displayView, with: commandBuffer)
    }

    func setDrawingTool(_ drawingTool: DrawingToolType) {
        canvasState.setDrawingTool(drawingTool)
    }
    func setBrushColor(_ color: UIColor) {
        canvasState.brush.color = color
    }
    func setBrushDiameter(_ value: Float) {
        canvasState.brush.setDiameter(value)
    }
    func setEraserDiameter(_ value: Float) {
        canvasState.eraser.setDiameter(value)
    }

    func newCanvas(configuration: CanvasConfiguration) {
        transformer.setMatrix(.identity)
        initialize(
            configuration: CanvasConfiguration(textureSize: canvasState.textureSize)
        )
    }

    func undo() {
        undoStack?.undo()
    }
    func redo() {
        undoStack?.redo()
    }

    func loadFile(zipFileURL: URL) {
        /// Create the working space
        do {
            try localFileRepository.createWorkingDirectory()
        }
        catch(let error) {
            alertSubject.send(error)
        }

        /// Unzip into the working space
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
                /// Restore the repository from the extracted textures
                return self.textureLayerRepository.restoreStorage(
                    from: workingDirectoryURL,
                    with: configuration
               )
           } catch(let error) {
               return Fail(error: error).eraseToAnyPublisher()
           }
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.toastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.alertSubject.send(error)
            }
            /// Remove the working space
            self?.localFileRepository.removeWorkingDirectory()

        }, receiveValue: { [weak self] configuration in
            Task { @MainActor in
                self?.setupCanvas(configuration)
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

        let zipFileURL = FileManager.documentsFileURL(
            projectName: canvasState.projectName,
            suffix: CanvasViewModel.fileSuffix
        )
        let entity = CanvasEntity(
            thumbnailName: CanvasEntity.thumbnailName,
            canvasState: canvasState
        )

        /// Create the working space
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
                /// Save the thumbnail to the working space
                self.localFileRepository.saveToWorkingDirectory(
                    namedItem: .init(name: CanvasEntity.thumbnailName, item: thumbnail)
                ),
                /// Save the textures to the working space
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
            /// Save canvas the data to the working space
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
            /// Archive the working space as a ZIP file
            try self?.localFileRepository.zipWorkingDirectory(
                to: zipFileURL
            )
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in self?.activityIndicatorSubject.send(true) },
            receiveCompletion: { [weak self] _ in self?.activityIndicatorSubject.send(false) }
        )
        .sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .finished: self?.toastSubject.send(.init(title: "Success", systemName: "hand.thumbsup.fill"))
            case .failure(let error): self?.alertSubject.send(error)
            }
            /// Remove the working space
            self?.localFileRepository.removeWorkingDirectory()

        }, receiveValue: {})
        .store(in: &cancellables)
    }
}

extension CanvasViewModel {

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard
            let drawableSize = displayView?.displayTexture?.size,
            let diameter = canvasState.drawingToolDiameter
        else { return }

        drawingCurve?.append(
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

        drawingDisplayLink.run(drawingCurve?.isCurrentlyDrawing ?? false)
    }

    private func transformCanvas() {
        guard let commandBuffer = displayView?.commandBuffer else { return }

        transformer.initTransformingIfNeeded(
            fingerStroke.touchHistories
        )

        if fingerStroke.isAllFingersOnScreen {
            transformer.transformCanvas(
                screenCenter: .init(
                    x: renderer.frameSize.width * 0.5,
                    y: renderer.frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )
        } else {
            transformer.finishTransforming()
        }

        renderer.updateCanvasView(displayView, with: commandBuffer)
    }

}

extension CanvasViewModel {

    private func cancelFingerDrawing() {
        guard let commandBuffer = displayView?.commandBuffer else { return }

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        drawingTextureSet?.clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerStroke.reset()

        drawingCurve = nil
        transformer.resetMatrix()

        displayView?.resetCommandBuffer()

        renderer.updateCanvasView(displayView, with: commandBuffer)
    }

    private func completeDrawing(texture: MTLTexture, for selectedTextureId: UUID) {
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
        touchGestureStatus.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        drawingCurve = nil
        transformer.resetMatrix()
    }

    func updateCanvasByMergingAllLayers() {
        guard
            let commandBuffer = displayView?.commandBuffer
        else { return }

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            textureLayerRepository: textureLayerRepository,
            with: commandBuffer
        ) { [weak self] in
            self?.updateCanvasView()
        }
    }

    func updateCanvasView(realtimeDrawingTexture: MTLTexture? = nil) {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let commandBuffer = displayView?.commandBuffer
        else { return }

        renderer.updateCanvasView(
            displayView,
            realtimeDrawingTexture: realtimeDrawingTexture,
            selectedLayer: selectedLayer,
            with: commandBuffer
        )
    }

}

enum CanvasViewModelError: Error {
    case invalidValue(String)
}
