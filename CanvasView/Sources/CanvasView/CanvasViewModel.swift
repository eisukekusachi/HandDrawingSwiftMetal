//
//  CanvasViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import UIKit

@MainActor
public final class CanvasViewModel {

    /// The frame size, which changes when the screen rotates or the view layout updates.
    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.frameSize = frameSize
            drawingRenderers.forEach { $0.setFrameSize(frameSize) }
        }
    }

    var zipFileURL: URL {
        projectMetaDataStorage.zipFileURL
    }

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `TextureLayersProtocol` when `TextureLayers` setup is prepared
    var didInitializeTextures: AnyPublisher<any TextureLayersProtocol, Never> {
        didInitializeTexturesSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `ResolvedTextureLayerArrayConfiguration` when the canvas view setup is completed
    var didInitializeCanvasView: AnyPublisher<ResolvedTextureLayerArrayConfiguration, Never> {
        didInitializeCanvasViewSubject.eraseToAnyPublisher()
    }

    private var dependencies: CanvasViewDependencies!

    /// Metadata stored in Core Data
    private var projectMetaDataStorage: CoreDataProjectMetaDataStorage

    /// Undoable texture layers
    private let textureLayers: UndoTextureLayers

    private let persistenceController: PersistenceController

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

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    private let transforming = Transforming()

    /// Manages input from pen and finger
    private let inputDevice = InputDeviceState()

    /// Manages on-screen gestures such as drag and pinch
    private let touchGesture = TouchGestureState()

    //private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    /// Emit `TextureLayersProtocol` when the texture update is completed
    private let didInitializeTexturesSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    /// Emit `ResolvedTextureLayerArrayConfiguration` when the canvas view update is completed
    private let didInitializeCanvasViewSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    /// A debouncer that ensures only the last operation is executed when drawing occurs rapidly
    private let persistanceDrawingDebouncer = Debouncer(delay: 0.25)

    private var cancellables = Set<AnyCancellable>()

    public static let thumbnailName: String = "thumbnail.png"

    public static let thumbnailLength: CGFloat = 500

    init() {
        canvasRenderer = CanvasRenderer()

        persistenceController = PersistenceController(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )

        // Initialize texture layers that supports undo and stores its data in Core Data
        textureLayers = UndoTextureLayers(
            textureLayers: CoreDataTextureLayers(
                canvasRenderer: canvasRenderer,
                context: persistenceController.viewContext
            ),
            canvasRenderer: canvasRenderer
        )

        projectMetaDataStorage = CoreDataProjectMetaDataStorage(
            project: ProjectMetaData(),
            context: persistenceController.viewContext
        )

        Task {
            if let entity = try projectMetaDataStorage.fetch() {
                projectMetaDataStorage.update(entity)
            }
        }
    }

    func setup(
        drawingRenderers: [DrawingRenderer],
        dependencies: CanvasViewDependencies,
        configuration: CanvasConfiguration
    ) async throws {
        self.dependencies = dependencies

        self.drawingRenderers = drawingRenderers
        if self.drawingRenderers.isEmpty {
            self.drawingRenderers = [BrushDrawingRenderer()]
        }
        self.drawingRenderers.forEach {
            $0.setup(frameSize: frameSize, displayView: dependencies.displayView, renderer: dependencies.renderer)
        }

        self.drawingRenderer = self.drawingRenderers[0]

        self.canvasRenderer.initialize(
            displayView: dependencies.displayView,
            renderer: dependencies.renderer,
            environmentConfiguration: configuration.environmentConfiguration
        )

        // Set the gesture recognition durations in seconds
        self.touchGesture.setDrawingGestureRecognitionSecond(
            configuration.environmentConfiguration.drawingGestureRecognitionSecond
        )
        self.touchGesture.setTransformingGestureRecognitionSecond(
            configuration.environmentConfiguration.transformingGestureRecognitionSecond
        )

        // If `undoTextureRepository` is used, undo functionality is enabled
        if let undoTextureRepository = self.dependencies.undoTextureRepository {
            self.textureLayers.setUndoTextureRepository(
                undoTextureRepository: undoTextureRepository
            )
        }

        bindData()

        // Use the size from CoreData if available,
        // if not, use the size from the configuration
        let textureLayersConfiguration: TextureLayerArrayConfiguration = .init(
            entity: try? (textureLayers.textureLayers as? CoreDataTextureLayers)?.fetch()
        ) ?? configuration.textureLayerArrayConfiguration

        // Initialize the texture repository
        let resolvedTextureLayersConfiguration = try await dependencies.textureRepository.initializeStorage(
            configuration: textureLayersConfiguration,
            fallbackTextureSize: TextureLayerModel.defaultTextureSize()
        )
        try await initializeTextures(resolvedTextureLayersConfiguration)
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.updatePublisher
            .sink { [weak self] in
                self?.drawPointsOnDisplayLink()
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayers.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.commitAndRefreshDisplay()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayers.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                guard let `self` else { return }
                Task {
                    // Set the texture of the selected texture layer to the renderer
                    try await self.canvasRenderer.updateSelectedLayerTexture(
                        textureLayers: self.textureLayers,
                        textureRepository: self.dependencies.textureRepository
                    )

                    self.commitAndRefreshDisplay()
                }
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer.matrix = matrix
            }
            .store(in: &cancellables)

        textureLayers.didUndo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didUndoSubject.send(state)
            }
            .store(in: &cancellables)
    }

    private func initializeTextures(_ configuration: ResolvedTextureLayerArrayConfiguration) async throws {
        // Initialize the textures used in the texture layers
        await textureLayers.initialize(
            configuration: configuration,
            textureRepository: dependencies.textureRepository
        )

        // Initialize the repository used for Undo
        if textureLayers.isUndoEnabled {
            textureLayers.initializeUndoTextureRepository(
                configuration.textureSize
            )
        }

        // Initialize the textures used in the drawing tool
        for i in 0 ..< drawingRenderers.count {
            drawingRenderers[i].initializeTextures(configuration.textureSize)
        }

        // Initialize the textures used in the renderer
        canvasRenderer.initializeTextures(
            textureSize: configuration.textureSize
        )

        // Set the texture of the selected texture layer to the renderer
        try await canvasRenderer.updateSelectedLayerTexture(
            textureLayers: textureLayers,
            textureRepository: dependencies.textureRepository
        )

        didInitializeTexturesSubject.send(textureLayers)
        didInitializeCanvasViewSubject.send(configuration)

        // Update to the latest date
        projectMetaDataStorage.updateUpdatedAt()

        commitAndRefreshDisplay()
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
                fingerStroke.beginFingerStroke()

                drawingRenderer.beginFingerStroke()

                Task {
                    await textureLayers.setUndoDrawing(
                        texture: canvasRenderer.selectedLayerTexture
                    )
                }
            }

            let pointArray = fingerStroke.drawingPoints(after: fingerStroke.drawingLineEndPoint)

            // Update the touch phase for drawing
            drawingTouchPhase = touchPhase(pointArray)

            drawingRenderer.appendPoints(
                screenTouchPoints: pointArray,
                matrix: transforming.matrix.inverted(flipY: true)
            )
            fingerStroke.updateDrawingLineEndPoint()

            drawingDisplayLink.run(isDrawing)

        case .transforming:
            transformCanvas()

        default: break
        }

        // Remove unused finger arrays from the dictionary
        fingerStroke.removeEndedTouchArrayFromDictionary()

        // Reset all parameters when all fingers are lifted off the screen
        if UITouch.isAllFingersReleasedFromScreen(touches: touches, with: event) {
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

            Task {
                await textureLayers.setUndoDrawing(
                    texture: canvasRenderer.selectedLayerTexture
                )
            }
        }

        pencilStroke.appendActualTouches(
            actualTouches: actualTouches
                .sorted { $0.timestamp < $1.timestamp }
                .map { TouchPoint(touch: $0, view: view) }
        )

        let pointArray = pencilStroke.drawingPoints(after: pencilStroke.drawingLineEndPoint)

        // Update the touch phase for drawing
        drawingTouchPhase = touchPhase(pointArray)

        drawingRenderer.appendPoints(
            screenTouchPoints: pointArray,
            matrix: transforming.matrix.inverted(flipY: true)
        )
        pencilStroke.updateDrawingLineEndPoint()

        drawingDisplayLink.run(isDrawing)
    }
}

public extension CanvasViewModel {

    func resetTransforming() {
        transforming.setMatrix(.identity)
        canvasRenderer.commitAndRefreshDisplay()
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard drawingToolIndex < drawingRenderers.count else { return }
        drawingRenderer = drawingRenderers[drawingToolIndex]
        drawingRenderer?.prepareNextStroke()
    }

    func newCanvas(configuration: TextureLayerArrayConfiguration) async throws {
        // Initialize the texture repository
        let resolvedConfiguration = try await dependencies.textureRepository.initializeStorage(
            configuration: configuration,
            fallbackTextureSize: TextureLayerModel.defaultTextureSize()
        )
        try await initializeTextures(resolvedConfiguration)

        transforming.setMatrix(.identity)

        projectMetaDataStorage.update()
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

        // Load texture layer data from the JSON file
        let textureLayersModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )

        let resolvedTextureLayersConfiguration: ResolvedTextureLayerArrayConfiguration = try await dependencies.textureRepository.restoreStorage(
            from: workingDirectoryURL,
            configuration: .init(
                textureSize: textureLayersModel.textureSize,
                layerIndex: textureLayersModel.layerIndex,
                layers: textureLayersModel.layers
            ),
            fallbackTextureSize: TextureLayerModel.defaultTextureSize()
        )

        // Restore the textures
        try await initializeTextures(resolvedTextureLayersConfiguration)

        // Load project metadata, falling back if it is missing
        let projectMetaData: ProjectMetaDataArchiveModel? = try? .init(
            in: workingDirectoryURL
        )

        // Update metadata
        projectMetaDataStorage.update(
            projectName: projectMetaData?.projectName ?? workingDirectoryURL.fileName,
            createdAt: projectMetaData?.createdAt ?? Date(),
            updatedAt: projectMetaData?.updatedAt ?? Date()
        )
    }

    func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {

        let device = canvasRenderer.device

        // Save the thumbnail image into the working directory
        try thumbnail(length: thumbnailLength)?.pngData()?.write(
            to: workingDirectoryURL.appendingPathComponent(CanvasViewModel.thumbnailName)
        )

        // Copy all textures from the textureRepository
        let textures = try await dependencies.textureRepository.duplicatedTextures(
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

    private var isDrawing: Bool {
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
            let commandBuffer = canvasRenderer.commandBuffer
        else { return }

        drawingRenderer.drawStroke(
            selectedLayerTexture: selectedLayerTexture,
            with: commandBuffer
        )

        // The finalization process is performed when drawing is completed.
        if isFinishedDrawing {
            drawingRenderer.endStroke(
                selectedLayerTexture: selectedLayerTexture,
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
            displayedLayer: isDrawing ? drawingRenderer.realtimeDrawingTexture : nil
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
            let layerId = textureLayers.selectedLayer?.id,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        persistanceDrawingDebouncer.scheduleAsync { [weak self] in
            do {
                try await self?.dependencies.textureRepository.updateTexture(
                    texture: selectedLayerTexture,
                    for: layerId
                )

                // Update `updatedAt` when drawing completes
                self?.projectMetaDataStorage.updateUpdatedAt()

                self?.textureLayers.updateThumbnail(
                    layerId,
                    texture: selectedLayerTexture
                )
            } catch {
                Logger.error(error)
            }
        }

        Task {
            await textureLayers.pushUndoDrawingObjectToUndoStack(
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

        if fingerStroke.isAllFingersOnScreen {
            transforming.transformCanvas(
                screenCenter: .init(
                    x: canvasRenderer.frameSize.width * 0.5,
                    y: canvasRenderer.frameSize.height * 0.5
                ),
                touchHistories: fingerStroke.touchHistories
            )
        } else {
            transforming.endTransformation()
        }

        canvasRenderer.commitAndRefreshDisplay()
    }

    private func commitAndRefreshDisplay(
        displayedLayer: RealtimeDrawingTexture? = nil
    ) {
        guard let selectedLayer = textureLayers.selectedLayer else { return }

        canvasRenderer.commitAndRefreshDisplay(
            displayedLayer: displayedLayer,
            selectedLayer: selectedLayer
        )
    }
}
