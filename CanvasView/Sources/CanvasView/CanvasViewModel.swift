//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import UIKit

/// A view model that manages canvas rendering and texture layers.
/// `TextureLayers` holds multiple layers, `DrawingRenderer` manages real-time drawing,
/// and `CanvasRenderer` combines them to output to DisplayTexture.
@MainActor
public final class CanvasViewModel {

    /// The frame size, which changes when the screen rotates or the view layout updates.
    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.setFrameSize(frameSize)
            drawingRenderers.forEach { $0.setFrameSize(frameSize) }
        }
    }

    var zipFileURL: URL {
        projectMetaDataStorage.zipFileURL
    }

    /// Emits `true` while drawing is in progress
    var isDrawing: AnyPublisher<Bool, Never> {
        isDrawingSubject.eraseToAnyPublisher()
    }
    private let isDrawingSubject = PassthroughSubject<Bool, Never>()

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    /// A publisher that emits `ResultConfiguration` when `CanvasViewModel` setup completes
    var didInitialize: AnyPublisher<ResultConfiguration, Never> {
        didInitializeSubject.eraseToAnyPublisher()
    }
    private let didInitializeSubject = PassthroughSubject<ResultConfiguration, Never>()

    /// Metadata stored in Core Data
    private var projectMetaDataStorage: CoreDataProjectMetaDataStorage

    /// Undoable texture layers
    private let textureLayers: UndoTextureLayers

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// A class that manages drawing lines onto textures
    private var drawingRenderer: DrawingRenderer?
    private var drawingRenderers: [DrawingRenderer] = []

    /// Touch phase for drawing
    private var drawingTouchPhase: UITouch.Phase?

    /// A display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

    /// A debouncer used to prevent continuous input during drawing
    private let drawingDebouncer: DrawingDebouncer

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    private let transforming = Transforming()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    /// A debouncer that ensures only the last operation is executed when drawing occurs rapidly
    private let persistanceDrawingDebouncer = Debouncer(delay: 0.25)

    private let persistenceController: PersistenceController

    private var dependencies: CanvasViewDependencies?

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailName: String = "thumbnail.png"

    public static let thumbnailLength: CGFloat = 500

    private var currentTextureSize: CGSize

    init(
        currentTextureSize: CGSize = .init(width: 768, height: 1024),
        renderer: MTLRendering
    ) {
        self.currentTextureSize = currentTextureSize

        canvasRenderer = CanvasRenderer(renderer: renderer)
        drawingDebouncer = DrawingDebouncer(delay: 0.25)
        persistenceController = PersistenceController(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )
        projectMetaDataStorage = CoreDataProjectMetaDataStorage(
            project: ProjectMetaData(),
            context: persistenceController.viewContext
        )
        // Initialize texture layers that support undo and persist their data in Core Data
        textureLayers = UndoTextureLayers(
            textureLayers: CoreDataTextureLayers(
                renderer: renderer,
                context: persistenceController.viewContext
            ),
            renderer: renderer
        )

        bindData()
    }

    func setup(
        configuration: CanvasConfiguration,
        dependencies: CanvasViewDependencies,
        drawingRenderers: [DrawingRenderer]
    ) async throws {
        self.dependencies = dependencies
        self.drawingRenderers = drawingRenderers
        self.currentTextureSize = configuration.textureSize

        setupCanvasRenderer(
            displayView: dependencies.displayView,
            environmentConfiguration: configuration.environmentConfiguration
        )
        setupDrawingRenderers(
            renderer: dependencies.renderer,
            displayView: dependencies.displayView
        )
        setupTouchGesture(environmentConfiguration: configuration.environmentConfiguration)
        setupUndoTextureLayersIfAvailable(undoTextureRepository: dependencies.undoTextureRepository)
        setupMetaDataIfAvailable()

        try await initCanvas(
            configuration: configuration,
            dependencies: dependencies
        )

        self.drawingRenderer = self.drawingRenderers[0]
    }
}

extension CanvasViewModel {
    func initCanvas(
        configuration: CanvasConfiguration,
        dependencies: CanvasViewDependencies
    ) async throws {
        var textureLayersState: ResolvedTextureLayersPersistedState?

        // Use the size from CoreData if available,
        // if not, use the default size
        if let state: ResolvedTextureLayersPersistedState = .init(
            entity: try? (textureLayers.textureLayers as? CoreDataTextureLayers)?.fetch()
        ) {
            // Initialize the texture repository
            textureLayersState = try await dependencies.textureDocumentsDirectoryRepository.initializeStorage(
                textureLayersPersistedState: state,
                fallbackTextureSize: configuration.textureSize
            )
        } else {
            textureLayersState = try await dependencies.textureDocumentsDirectoryRepository.initializeStorage(
                newTextureSize: CanvasView.defaultTextureSize
            )
        }

        guard let textureLayersState else { return }

        try await initializeTextureLayers(textureLayersState: textureLayersState)

        // Update only the updatedAt field, since the metadata may be loaded from Core Data
        projectMetaDataStorage.updateUpdatedAt()

        commitAndRefreshDisplay()

        didInitializeSubject.send(
            .init(
                textureLayers: textureLayers,
                resolvedTextureLayersPersistedState: textureLayersState
            )
        )
    }

    func newCanvas(
        newProjectName: String,
        dependencies: CanvasViewDependencies
    ) async throws {
        // Initialize the texture repository
        let textureLayersState = try await dependencies.textureDocumentsDirectoryRepository.initializeStorage(
            newTextureSize: currentTextureSize
        )
        try await initializeTextureLayers(textureLayersState: textureLayersState)

        // Update the metadata with a new name
        projectMetaDataStorage.update(
            newProjectName: newProjectName
        )

        commitAndRefreshDisplay()

        didInitializeSubject.send(
            .init(
                textureLayers: textureLayers,
                resolvedTextureLayersPersistedState: textureLayersState
            )
        )
    }

    func restoreCanvas(
        workingDirectoryURL: URL,
        textureLayersPersistedState: TextureLayersPersistedState,
        projectMetaData: ProjectMetaData,
        dependencies: CanvasViewDependencies
    ) async throws {
        let resolvedTextureLayers = try await dependencies.textureDocumentsDirectoryRepository.restoreStorage(
            from: workingDirectoryURL,
            textureLayersPersistedState: textureLayersPersistedState,
            fallbackTextureSize: CanvasView.defaultTextureSize
        )

        try await initializeTextureLayers(textureLayersState: resolvedTextureLayers)

        // Update metadata
        projectMetaDataStorage.update(
            projectName: projectMetaData.projectName,
            createdAt: projectMetaData.createdAt,
            updatedAt: projectMetaData.updatedAt
        )

        commitAndRefreshDisplay()

        didInitializeSubject.send(
            .init(
                textureLayers: textureLayers,
                resolvedTextureLayersPersistedState: resolvedTextureLayers
            )
        )
    }
}

extension CanvasViewModel {
    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.updatePublisher
            .sink { [weak self] in
                self?.drawPointsOnDisplayLink()
            }
            .store(in: &cancellables)

        // Execute when the drawing is complete
        drawingDebouncer.isProcessing
            .sink { [weak self] isProcessing in
                if !isProcessing {
                    // Set isDrawingSubject to false when drawing is complete
                    self?.isDrawingSubject.send(false)
                }
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayers.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)

        // Update the canvas with `RealtimeDrawingTexture`
        textureLayers.canvasDrawingUpdateRequested
            .sink { [weak self] texture in
                guard
                    let `self`,
                    let commandBuffer = self.canvasRenderer.commandBuffer
                else { return }

                self.canvasRenderer.updateSelectedLayerTextures(
                    texture: texture,
                    with: commandBuffer
                )
                self.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayers.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                guard let `self`, let dependencies else { return }
                Task {
                    try await self.canvasRenderer.updateTextures(
                        textureLayers: self.textureLayers,
                        textureDocumentsDirectoryRepository: dependencies.textureDocumentsDirectoryRepository
                    )

                    self.commitAndRefreshDisplay()
                }
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer.setMatrix(matrix)
            }
            .store(in: &cancellables)

        textureLayers.didUndo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didUndoSubject.send(state)
            }
            .store(in: &cancellables)
    }

    private func initializeTextureLayers(textureLayersState: ResolvedTextureLayersPersistedState) async throws {
        guard let dependencies else { return }

        // Initialize the textures used in the texture layers
        await textureLayers.initialize(
            configuration: textureLayersState,
            textureDocumentsDirectoryRepository: dependencies.textureDocumentsDirectoryRepository
        )

        // Initialize the repository used for Undo
        if textureLayers.isUndoEnabled {
            textureLayers.initializeUndoTextureRepository(
                textureSize: textureLayersState.textureSize
            )
        }

        // Initialize the textures used in the drawing tool
        for i in 0 ..< drawingRenderers.count {
            try drawingRenderers[i].initializeTextures(textureLayersState.textureSize)
        }

        // Initialize the textures used in the renderer
        canvasRenderer.initializeTextures(
            textureSize: textureLayersState.textureSize
        )

        try await canvasRenderer.updateTextures(
            textureLayers: textureLayers,
            textureDocumentsDirectoryRepository: dependencies.textureDocumentsDirectoryRepository
        )
    }

    private func setupDrawingRenderers(
        renderer: MTLRendering,
        displayView: CanvasDisplayable
    ) {
        if self.drawingRenderers.isEmpty {
            self.drawingRenderers = [BrushDrawingRenderer()]
        }
        self.drawingRenderers.forEach {
            $0.setup(
                frameSize: frameSize,
                renderer: renderer,
                displayView: displayView
            )
        }
    }
    private func setupCanvasRenderer(
        displayView: CanvasDisplayable?,
        environmentConfiguration: EnvironmentConfiguration
    ) {
        self.canvasRenderer.initialize(
            displayView: displayView,
            backgroundColor: environmentConfiguration.backgroundColor,
            baseBackgroundColor: environmentConfiguration.baseBackgroundColor
        )
    }
    private func setupTouchGesture(environmentConfiguration: EnvironmentConfiguration) {
        // Set the gesture recognition durations in seconds
        self.touchGesture.setDrawingGestureRecognitionSecond(
            environmentConfiguration.drawingGestureRecognitionSecond
        )
        self.touchGesture.setTransformingGestureRecognitionSecond(
            environmentConfiguration.transformingGestureRecognitionSecond
        )
    }
    private func setupMetaDataIfAvailable() {
        // Use metadata from Core Data if available
        // Do nothing if it fails
        if let entity = try? projectMetaDataStorage.fetch() {
            projectMetaDataStorage.update(entity)
        }
    }
    private func setupUndoTextureLayersIfAvailable(undoTextureRepository: TextureInMemoryRepository?) {
        // If `undoTextureRepository` is used, undo functionality is available
        if let undoTextureRepository {
            self.textureLayers.setUndoTextureRepository(
                undoTextureInMemoryRepository: undoTextureRepository
            )
        }
    }
}

extension CanvasViewModel {

    /// Called when the display texture size changes, such as when the device orientation changes.
    func didChangeDisplayTextureSize(_ displayTextureSize: CGSize) {
        commitAndRefreshDisplay()
    }

    func onFingerGestureDetected(
        touches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        inputDevice.update(.finger)

        // Return if a pen input is in progress
        guard inputDevice.isNotPencil else { return }

        fingerStroke.appendTouchPointToDictionary(
            UITouch.getFingerTouches(event: event).reduce(into: [:]) {
                $0[$1.hashValue] = .init(touch: $1, view: view)
            }
        )

        // determine the gesture from the dictionary
        switch touchGesture.update(fingerStroke.touchHistories) {
        case .drawing:
            guard let drawingRenderer else { return }

            // Execute if finger drawing has not yet started
            if fingerStroke.isFingerDrawingInactive {

                // Store the drawing-specific key in the dictionary
                fingerStroke.storeKeyForDrawing()

                drawingRenderer.beginFingerStroke()

                isDrawingSubject.send(true)

                Task {
                    await textureLayers.setUndoDrawing(
                        texture: canvasRenderer.selectedLayerTexture
                    )
                }
            }

            let pointArray = fingerStroke.drawingPoints(after: fingerStroke.drawingLineEndPoint)

            // Update the touch phase for drawing
            drawingTouchPhase = touchPhase(pointArray)

            drawingRenderer.onStroke(
                screenTouchPoints: pointArray,
                matrix: transforming.matrix.inverted(flipY: true)
            )
            fingerStroke.updateDrawingLineEndPoint()

            drawingDisplayLink.run(isCurrentlyDrawing)

        case .transforming:
            transformCanvas()

        default: break
        }

        // Remove unused finger arrays from the dictionary
        fingerStroke.removeEndedTouchArrayFromDictionary()

        // Reset all parameters when all fingers are lifted off the screen
        if UITouch.isAllFingersReleasedFromScreen(event: event) {
            resetFingerGestureParameters()
        }
    }

    func onPencilGestureDetected(
        estimatedTouches: Set<UITouch>,
        with event: UIEvent?,
        view: UIView
    ) {
        // Reset parameters if a finger drawing is in progress
        if inputDevice.isFinger {
            resetTouchRelatedParameters()
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
        guard let drawingRenderer else { return }

        /// Execute if it’s the beginning of a touch
        if actualTouches.contains(where: { $0.phase == .began }) {

            drawingRenderer.beginPencilStroke()

            isDrawingSubject.send(true)

            Task {
                await textureLayers.setUndoDrawing(
                    texture: canvasRenderer.selectedLayerTexture
                )
            }
        }

        pencilStroke.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { .init(touch: $0, view: view) }
        )

        let pointArray = pencilStroke.drawingPoints(after: pencilStroke.drawingLineEndPoint)

        // Update the touch phase for drawing
        drawingTouchPhase = touchPhase(pointArray)

        drawingRenderer.onStroke(
            screenTouchPoints: pointArray,
            matrix: transforming.matrix.inverted(flipY: true)
        )
        pencilStroke.updateDrawingLineEndPoint()

        drawingDisplayLink.run(isCurrentlyDrawing)
    }

    func onTapNewCanvas(
        newProjectName: String,
        newTextureSize: CGSize
    ) async throws {
        guard let dependencies else { return }

        try await newCanvas(
            newProjectName: newProjectName,
            dependencies: dependencies
        )

        transforming.setMatrix(.identity)
    }
}

public extension CanvasViewModel {

    func resetTransforming() {
        transforming.setMatrix(.identity)
        canvasRenderer.commitAndRefreshDisplay()
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard
            drawingToolIndex < drawingRenderers.count
        else { return }

        drawingRenderer = drawingRenderers[drawingToolIndex]
        drawingRenderer?.prepareNextStroke()
    }

    func undo() {
        textureLayers.undo()
    }
    func redo() {
        textureLayers.redo()
    }
}

public extension CanvasViewModel {

    func thumbnail(length: CGFloat = CanvasViewModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }

    func loadFiles(
        in workingDirectoryURL: URL
    ) async throws {
        guard let dependencies else { return }

        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )

        // Load project metadata, falling back if it is missing
        let projectMetaData: ProjectMetaDataArchiveModel? = try? .init(
            in: workingDirectoryURL
        )

        try await restoreCanvas(
            workingDirectoryURL: workingDirectoryURL,
            textureLayersPersistedState: .init(textureLayersArchiveModel),
            projectMetaData: .init(projectMetaData: projectMetaData, fallbacName: workingDirectoryURL.fileName),
            dependencies: dependencies
        )
    }

    func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {
        guard let dependencies else { return }

        let device = canvasRenderer.device

        // Save the thumbnail image into the working directory
        try thumbnail(length: thumbnailLength)?.pngData()?.write(
            to: workingDirectoryURL.appendingPathComponent(CanvasViewModel.thumbnailName)
        )

        // Copy all textures from the textureRepository
        let textures = try await dependencies.textureDocumentsDirectoryRepository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for texture in textures {
                group.addTask {
                    try await texture.write(
                        in: workingDirectoryURL,
                        device: device
                    )
                }
            }
            try await group.waitForAll()
        }

        // Save the texture layers as JSON
        try TextureLayersArchiveModel(
            textureSize: textureLayers.textureSize,
            layerIndex: textureLayers.selectedIndex ?? 0,
            layers: textureLayers.layers.map { .init(item: $0) }
        ).write(
            in: workingDirectoryURL
        )

        // Save the project metadata as JSON
       try ProjectMetaDataArchiveModel(
            projectName: projectMetaDataStorage.projectName,
            createdAt: projectMetaDataStorage.createdAt,
            updatedAt: projectMetaDataStorage.updatedAt
        ).write(
            in: workingDirectoryURL
        )
    }
}

extension CanvasViewModel {

    private var isCurrentlyDrawing: Bool {
        switch drawingTouchPhase {
        case .began, .moved: return true
        default: return false
        }
    }
    private var isFinishedDrawing: Bool {
        drawingTouchPhase == .ended
    }
    private var isCancelledDrawing: Bool {
        drawingTouchPhase == .cancelled
    }

    private func touchPhase(_ points: [TouchPoint]) -> UITouch.Phase? {
        if points.contains(where: { $0.phase == .cancelled }) {
            return .cancelled
        } else if points.contains(where: { $0.phase == .ended }) {
            return .ended
        } else if points.contains(where: { $0.phase == .began }) {
            return .began
        } else if points.contains(where: { $0.phase == .moved }) {
            return .moved
        }
        return nil
    }

    private func drawPointsOnDisplayLink() {
        guard
            let drawingRenderer,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture,
            let realtimeDrawingTexture = canvasRenderer.realtimeDrawingTexture,
            let commandBuffer = canvasRenderer.commandBuffer
        else { return }

        drawingRenderer.drawStroke(
            selectedLayerTexture: selectedLayerTexture,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        // The finalization process is performed when drawing is completed.
        if isFinishedDrawing {
            canvasRenderer.renderToSelectedLayer(
                texture: canvasRenderer.realtimeDrawingTexture,
                with: commandBuffer
            )

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor [weak self] in
                    // Reset parameters on drawing completion
                    self?.prepareNextStroke()

                    self?.completeDrawing()
                }
            }
        } else if isCancelledDrawing {
            // Prepare for the next drawing when the drawing is cancelled.
            prepareNextStroke()
        }

        commitAndRefreshDisplay(
            displayRealtimeDrawingTexture: drawingRenderer.displayRealtimeDrawingTexture
        )
    }

    private func prepareNextStroke() {

        inputDevice.reset()
        touchGesture.reset()

        fingerStroke.reset()
        pencilStroke.reset()

        transforming.resetMatrix()

        drawingDisplayLink.stop()

        drawingTouchPhase = nil

        drawingRenderer?.prepareNextStroke()
    }

    private func resetFingerGestureParameters() {

        touchGesture.reset()

        fingerStroke.reset()
        drawingDisplayLink.stop()
    }
    private func resetTouchRelatedParameters() {

        fingerStroke.reset()

        transforming.resetMatrix()

        drawingRenderer?.prepareNextStroke()

        canvasRenderer.resetCommandBuffer()
        canvasRenderer.commitAndRefreshDisplay()
    }

    private func completeDrawing() {
        guard
            let dependencies,
            let layerId = textureLayers.selectedLayer?.id,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        drawingDebouncer.perform { [weak self] in
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.textureDocumentsDirectoryRepository.writeTextureToDisk(
                        texture: selectedLayerTexture,
                        for: layerId
                    )

                    self.textureLayers.updateThumbnail(
                        layerId,
                        texture: selectedLayerTexture
                    )

                    // Update `updatedAt` when drawing completes
                    self.projectMetaDataStorage.updateUpdatedAt()

                } catch {
                    Logger.error(error)
                }
            }
        }

        Task {
            try await textureLayers.pushUndoDrawingObjectToUndoStack(
                texture: selectedLayerTexture
            )
        }
    }

    private func transformCanvas() {
        if transforming.isNotKeysInitialized {
            transforming.initialize(
                fingerStroke.touchHistories
            )
        }

        if fingerStroke.hasEndedTouches {
            transforming.endTransformation()
        } else {
            transforming.transformCanvas(
                screenCenter: .init(
                    x: frameSize.width * 0.5,
                    y: frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )
        }

        canvasRenderer.commitAndRefreshDisplay()
    }

    private func commitAndRefreshDisplay(
        displayRealtimeDrawingTexture: Bool = false
    ) {
        guard let selectedLayer = textureLayers.selectedLayer else { return }

        canvasRenderer.commitAndRefreshDisplay(
            displayRealtimeDrawingTexture: displayRealtimeDrawingTexture,
            selectedLayer: selectedLayer
        )
    }
}
