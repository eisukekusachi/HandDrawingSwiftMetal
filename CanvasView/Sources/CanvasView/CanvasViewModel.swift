//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine

@preconcurrency import MetalKit

@MainActor
public final class CanvasViewModel {

    /// Maintains the state of the canvas
    let canvasState = CanvasState()

    public static var fileSuffix: String {
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
    var alert: AnyPublisher<ErrorModel, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    var toast: AnyPublisher<ToastModel, Never> {
        toastSubject.eraseToAnyPublisher()
    }

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `Void` when the canvas view setup is completed
    var canvasViewSetupCompleted: AnyPublisher<CanvasResolvedConfiguration, Never> {
        canvasViewSetupCompletedSubject.eraseToAnyPublisher()
    }

    var textureLayerConfiguration: TextureLayerConfiguration {
        .init(
            canvasState: canvasState,
            textureRepository: self.dependencies.textureRepository,
            undoStack: undoStack,
            defaultBackgroundColor: UIColor(named: "defaultBackgroundColor") ?? .clear,
            selectedBackgroundColor: UIColor(named: "selectedBackgroundColor") ?? .clear
        )
    }

    /// A rendering target
    private var displayView: CanvasDisplayable?

    private var dependencies: CanvasViewDependencies!

    /// It persists the canvas state to disk using `CoreData` when `textureRepository` is `TextureLayerDocumentsDirectorySingletonRepository`
    private var canvasStateStorage: CanvasStateStorage?

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    /// A texture set for realtime drawing
    private var drawingRenderer: DrawingRenderer?
    private var drawingRenderers: [DrawingRenderer] = []

    /// A display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    private var renderer = CanvasRenderer()

    private let transforming = Transforming()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<ErrorModel, Never>()

    private let toastSubject = PassthroughSubject<ToastModel, Never>()

    private let canvasViewSetupCompletedSubject = PassthroughSubject<CanvasResolvedConfiguration, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private var undoStack: UndoStack? = nil

    private var cancellables = Set<AnyCancellable>()

    func initialize(
        drawingRenderers: [DrawingRenderer],
        dependencies: CanvasViewDependencies,
        configuration: CanvasConfiguration,
        environmentConfiguration: CanvasEnvironmentConfiguration,
        defaultTextureSize: CGSize,
        displayView: CanvasDisplayable
    ) {
        self.drawingRenderers = drawingRenderers
        self.drawingRenderer = self.drawingRenderers[0]

        self.dependencies = dependencies

        self.renderer.initialize(
            environmentConfiguration: environmentConfiguration
        )

        // Set the gesture recognition durations in seconds
        self.touchGesture.setDrawingGestureRecognitionSecond(
            environmentConfiguration.drawingGestureRecognitionSecond
        )
        self.touchGesture.setTransformingGestureRecognitionSecond(
            environmentConfiguration.transformingGestureRecognitionSecond
        )

        // If `TextureLayerDocumentsDirectorySingletonRepository` is used, `CanvasStateStorage` is enabled
        if self.dependencies.textureRepository is TextureDocumentsDirectoryRepository {
            canvasStateStorage = CanvasStateStorage()
            canvasStateStorage?.setupStorage(canvasState)
        }

        /*
        // If `undoTextureRepository` is used, undo functionality is enabled
        if let undoTextureRepository = self.dependencies.undoTextureRepository {
            let textureRepository = self.dependencies.textureRepository
            undoStack = .init(
                canvasState: canvasState,
                textureRepository: textureRepository,
                undoTextureRepository: undoTextureRepository
            )
        }
        */

        self.displayView = displayView

        // Use the size from CoreData if available,
        // if not, use the size from the configuration
        Task {
            try await initializeCanvas(
                configuration: canvasStateStorage?.coreDataConfiguration ?? configuration,
                defaultTextureSize: defaultTextureSize
            )
            bindData()
        }
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

                self?.drawingRenderer?.drawCurve(
                    drawingCurve,
                    using: texture,
                    with: commandBuffer,
                    onDrawing: { [weak self] resultTexture in
                        self?.updateCanvasView(realtimeDrawingTexture: resultTexture)
                    },
                    onDrawingCompleted: { [weak self] resultTexture in

                        // Reset parameters on drawing completion
                        self?.resetAllInputParameters()

                        commandBuffer.addCompletedHandler { [weak self] _ in
                            Task { @MainActor in
                                self?.completeDrawing(texture: resultTexture, for: selectedLayerId)
                            }
                        }
                    }
                )
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

        canvasStateStorage?.alertSubject
            .sink { [weak self] error in
                self?.alertSubject.send(
                    ErrorModel.create(error)
                )
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .assign(to: \.matrix, on: renderer)
            .store(in: &cancellables)

        undoStack?.didUndo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didUndoSubject.send(state)
            }
            .store(in: &cancellables)
    }
}

public extension CanvasViewModel {

    var currentTextureSize: CGSize {
        canvasState.textureSize
    }

    func initializeCanvas(
        configuration: CanvasConfiguration,
        defaultTextureSize: CGSize
    ) async throws {
        // Initialize the texture repository
        let resolvedConfiguration = try await dependencies.textureRepository.initializeStorage(
            configuration: configuration,
            defaultTextureSize: defaultTextureSize
        )

        setupCanvas(resolvedConfiguration)
    }

    private func setupCanvas(_ configuration: CanvasResolvedConfiguration) {
        guard let commandBuffer = displayView?.commandBuffer else { return }

        canvasState.initialize(
            configuration: configuration,
            textureRepository: dependencies.textureRepository
        )

        renderer.initTextures(textureSize: configuration.textureSize)

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            textureRepository: dependencies.textureRepository,
            with: commandBuffer
        ) { [weak self] in
            self?.completeCanvasSetup(configuration: configuration)
        }
    }

    private func completeCanvasSetup(configuration: CanvasResolvedConfiguration) {
        for i in 0 ..< drawingRenderers.count {
            drawingRenderers[i].initTextures(configuration.textureSize)
        }

        undoStack?.initialize(configuration.textureSize)

        canvasViewSetupCompletedSubject.send(configuration)

        updateCanvasView()
    }
}

extension CanvasViewModel {

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        inputDevice.update(.finger)
        guard inputDevice.isNotPencil else { return }

        fingerStroke.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch touchGesture.update(fingerStroke.touchHistories) {
        case .drawing:
            if SmoothDrawingCurve.shouldCreateInstance(drawingCurve: drawingCurve) {
                drawingCurve = SmoothDrawingCurve()
                Task {
                    await undoStack?.setDrawingUndoObject()
                }
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
        if inputDevice.isFinger {
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
            Task {
                await undoStack?.setDrawingUndoObject()
            }
        }

        pencilStroke.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        drawCurveOnCanvas(pencilStroke.latestActualTouchPoints)
    }
}

public extension CanvasViewModel {

    func defaultTextureSize() -> CGSize {
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size

        return .init(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    func resetTransforming() {
        guard let commandBuffer = displayView?.commandBuffer else { return }
        transforming.setMatrix(.identity)
        renderer.updateCanvasView(displayView, with: commandBuffer)
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard drawingToolIndex < drawingRenderers.count else { return }
        drawingRenderer = drawingRenderers[drawingToolIndex]
    }

    func newCanvas(configuration: CanvasConfiguration) async throws {
        try await initializeCanvas(configuration: configuration, defaultTextureSize: defaultTextureSize())
        transforming.setMatrix(.identity)
    }

    func undo() {
        undoStack?.undo()
    }
    func redo() {
        undoStack?.redo()
    }

    func loadFile(zipFileURL: URL, candidates: [CanvasEntityConvertible.Type]) {
        Task {
            defer { activityIndicatorSubject.send(false) }
            activityIndicatorSubject.send(true)

            do {
                try dependencies.localFileRepository.createWorkingDirectory()

                let workingDirectoryURL = try await dependencies.localFileRepository.unzipToWorkingDirectoryAsync(
                    from: zipFileURL
                )

                let entity: CanvasEntity = try .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(CanvasEntity.jsonFileName),
                    candidates: candidates
                )
                let configuration: CanvasConfiguration = .init(
                    projectName: zipFileURL.fileName,
                    entity: entity
                )
                /// Restore the repository from the extracted textures
                let resolvedConfiguration = try await dependencies.textureRepository.restoreStorage(
                    from: workingDirectoryURL,
                    configuration: configuration,
                    defaultTextureSize: defaultTextureSize()
                )

                setupCanvas(resolvedConfiguration)

                /// Remove the working space
                dependencies.localFileRepository.removeWorkingDirectory()

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            }
            catch {
                alertSubject.send(
                    ErrorModel.create(
                        error as NSError,
                        title: String(localized: "Loading Error", bundle: .module)
                    )
                )
            }
        }
    }

    func saveFile(
        drawingTool: Int,
        brushDiameter: Int,
        eraserDiameter: Int
    ) {
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

        Task {
            defer { activityIndicatorSubject.send(false) }
            activityIndicatorSubject.send(true)

            do {
                try dependencies.localFileRepository.createWorkingDirectory()

                let result = try await dependencies.textureRepository.copyTextures(
                    uuids: canvasState.layers.map { $0.id }
                )

                async let resultThumbnail = try await dependencies.localFileRepository.saveToWorkingDirectory(
                    namedItem: .init(name: CanvasEntity.thumbnailName, item: thumbnail)
                )
                async let resultURLs: [URL] = try await dependencies.localFileRepository.saveAllToWorkingDirectory(
                    namedItems: result.map {
                        .init(name: $0.uuid.uuidString, item: $0)
                    }
                )
                _ = try await (resultThumbnail, resultURLs)

                async let resultEntity = try await dependencies.localFileRepository.saveToWorkingDirectory(
                    namedItem: .init(
                        name: CanvasEntity.jsonFileName,
                        item: entity
                    )
                )
                _ = try await (resultEntity)

                try dependencies.localFileRepository.zipWorkingDirectory(
                    to: zipFileURL
                )

                /// Remove the working space
                dependencies.localFileRepository.removeWorkingDirectory()

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                alertSubject.send(
                    ErrorModel.create(
                        error as NSError,
                        title: String(localized: "Saving Error", bundle: .module)
                    )
                )
            }
        }
    }
}

extension CanvasViewModel {

    private func drawCurveOnCanvas(_ screenTouchPoints: [TouchPoint]) {
        guard
            let drawingRenderer,
            let drawableSize = displayView?.displayTexture?.size
        else { return }

        drawingCurve?.append(
            points: drawingRenderer.curvePoints(
                screenTouchPoints,
                matrix: transforming.matrix.inverted(flipY: true),
                drawableSize: drawableSize,
                frameSize: renderer.frameSize
            ),
            touchPhase: screenTouchPoints.lastTouchPhase
        )

        drawingDisplayLink.run(drawingCurve?.isCurrentlyDrawing ?? false)
    }

    private func transformCanvas() {
        guard let commandBuffer = displayView?.commandBuffer else { return }

        if transforming.isNotKeysInitialized {
            transforming.initialize(
                fingerStroke.touchHistories
            )
        }

        if fingerStroke.isAllFingersOnScreen {
            transforming.transformCanvas(
                screenCenter: .init(
                    x: renderer.frameSize.width * 0.5,
                    y: renderer.frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )
        } else {
            transforming.endTransformation()
        }

        renderer.updateCanvasView(displayView, with: commandBuffer)
    }
}

extension CanvasViewModel {

    private func cancelFingerDrawing() {
        guard
            let commandBuffer = displayView?.commandBuffer,
            let device = MTLCreateSystemDefaultDevice(),
            let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()
        else { return }

        drawingRenderer?.clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()

        fingerStroke.reset()

        drawingCurve = nil
        transforming.resetMatrix()

        displayView?.resetCommandBuffer()

        renderer.updateCanvasView(displayView, with: commandBuffer)
    }

    private func completeDrawing(texture: MTLTexture, for selectedTextureId: UUID) {
        Task {
            do {
                let resultTexture = try await dependencies.textureRepository.updateTexture(
                    texture: texture,
                    for: selectedTextureId
                )
                await undoStack?.pushUndoDrawingObject(
                    texture: resultTexture.texture
                )
            } catch {
                // No action on error
                Logger.error(error)
            }
        }

        canvasState.updateThumbnail(
            .init(uuid: selectedTextureId, texture: texture)
        )
    }

    private func resetAllInputParameters() {
        inputDevice.reset()
        touchGesture.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        drawingCurve = nil
        transforming.resetMatrix()
    }

    func updateCanvasByMergingAllLayers() {
        guard
            let commandBuffer = displayView?.commandBuffer
        else { return }

        renderer.updateDrawingTextures(
            canvasState: canvasState,
            textureRepository: dependencies.textureRepository,
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
