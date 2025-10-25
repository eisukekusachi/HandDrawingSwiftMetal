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

    var frameSize: CGSize = .zero {
        didSet {
            canvasRenderer.frameSize = frameSize
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

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer

    /// Metadata stored in Core Data
    private var projectMetaDataStorage: CoreDataProjectMetaDataStorage

    /// Undoable texture layers
    private let textureLayers: UndoTextureLayers

    private let persistenceController: PersistenceController

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// A class that manages drawing lines onto textures
    private var drawingToolRenderer: DrawingToolRenderer?
    private var drawingToolRenderers: [DrawingToolRenderer] = []

    /// A display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

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
    private let undoDrawingDebouncer = Debouncer(delay: 0.1)

    private var cancellables = Set<AnyCancellable>()

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

    func initialize(
        drawingToolRenderers: [DrawingToolRenderer],
        dependencies: CanvasViewDependencies,
        configuration: CanvasConfiguration
    ) async throws {
        drawingToolRenderers.forEach {
            $0.initialize(displayView: dependencies.displayView, renderer: dependencies.renderer)
        }
        self.drawingToolRenderers = drawingToolRenderers

        self.drawingToolRenderer = self.drawingToolRenderers[0]

        self.dependencies = dependencies

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
                self?.drawCurvePointsOnCanvas()
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayers.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasView()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayers.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasByMergingAllLayers()
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
        for i in 0 ..< drawingToolRenderers.count {
            drawingToolRenderers[i].initializeTextures(configuration.textureSize)
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
        projectMetaDataStorage.refreshUpdatedAt()

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
                    await textureLayers.setUndoDrawing(
                        texture: canvasRenderer.selectedLayerTexture
                    )
                }
            }

            fingerStroke.setActiveDictionaryKeyIfNil()

            appendCurvePoints(fingerStroke.latestTouchPoints)

            drawingDisplayLink.run(drawingCurve?.isCurrentlyDrawing ?? false)

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

        appendCurvePoints(pencilStroke.latestActualTouchPoints)

        drawingDisplayLink.run(drawingCurve?.isCurrentlyDrawing ?? false)
    }
}

public extension CanvasViewModel {

    func resetTransforming() {
        transforming.setMatrix(.identity)
        canvasRenderer.updateCanvasView()
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard drawingToolIndex < drawingToolRenderers.count else { return }
        drawingToolRenderer = drawingToolRenderers[drawingToolIndex]
    }

    func newCanvas(configuration: TextureLayerArrayConfiguration) async throws {
        // Initialize the texture repository
        let resolvedConfiguration = try await dependencies.textureRepository.initializeStorage(
            configuration: configuration,
            fallbackTextureSize: TextureLayerModel.defaultTextureSize()
        )
        try await initializeTextures(resolvedConfiguration)

        transforming.setMatrix(.identity)

        projectMetaDataStorage.refresh()
    }

    func undo() {
        textureLayers.undo()
    }
    func redo() {
        textureLayers.redo()
    }
}

public extension CanvasViewModel {

    func thumbnail(length: CGFloat = TextureLayersArchiveModel.thumbnailLength) -> UIImage? {
        canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: length,
            scale: 1.0
        )
    }

    func loadFiles(
        textureLayersModel: TextureLayersArchiveModel,
        from workingDirectoryURL: URL
    ) async throws {

        let resolvedTextureLayersConfiguration: ResolvedTextureLayerArrayConfiguration = try await dependencies.textureRepository.restoreStorage(
            from: workingDirectoryURL,
            configuration: .init(
                textureSize: textureLayersModel.textureSize,
                layerIndex: textureLayersModel.layerIndex,
                layers: textureLayersModel.layers
            ),
            defaultTextureSize: TextureLayerModel.defaultTextureSize()
        )

        // Restore the textures
        try await initializeTextures(resolvedTextureLayersConfiguration)

        // Load project metadata, falling back if it is missing
        let projectMetaData: ProjectMetaDataArchiveModel? = try? .init(
            fileURL: workingDirectoryURL.appendingPathComponent(ProjectMetaDataArchiveModel.jsonFileName)
        )

        // Update metadata
        projectMetaDataStorage.update(
            projectName: projectMetaData?.projectName ?? workingDirectoryURL.fileName,
            createdAt: projectMetaData?.createdAt ?? Date(),
            updatedAt: projectMetaData?.updatedAt ?? Date()
        )
    }

    func exportFiles(
        thumbnailLength: CGFloat = TextureLayersArchiveModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {

        let device = canvasRenderer.device

        // Save the thumbnail image into the working directory
        try thumbnail(length: thumbnailLength)?.write(
            to: workingDirectoryURL.appendingPathComponent(TextureLayersArchiveModel.thumbnailName)
        )

        // Copy all textures from the textureRepository
        let textures = try await dependencies.textureRepository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for texture in textures {
                let fileName = texture.fileName
                group.addTask {
                    try await texture.write(
                        to: workingDirectoryURL.appendingPathComponent(fileName),
                        device: device
                    )
                }
            }
            try await group.waitForAll()
        }

        // Save the texture layers as JSON
        try TextureLayersArchiveModel(textureLayers: textureLayers).write(
            to: workingDirectoryURL.appendingPathComponent(TextureLayersArchiveModel.fileName)
        )

        // Save the project metadata as JSON
       try ProjectMetaDataArchiveModel(
            projectName: projectMetaDataStorage.projectName,
            createdAt: projectMetaDataStorage.createdAt,
            updatedAt: projectMetaDataStorage.updatedAt
        ).write(
            to: workingDirectoryURL.appendingPathComponent(ProjectMetaDataArchiveModel.jsonFileName)
        )
    }
}

extension CanvasViewModel {

    private func appendCurvePoints(_ screenTouchPoints: [TouchPoint]) {
        guard
            let drawingToolRenderer,
            let drawableSize = canvasRenderer.drawableSize
        else { return }

        drawingCurve?.append(
            points: drawingToolRenderer.curvePoints(
                screenTouchPoints,
                matrix: transforming.matrix.inverted(flipY: true),
                drawableSize: drawableSize,
                frameSize: canvasRenderer.frameSize
            ),
            touchPhase: screenTouchPoints.lastTouchPhase
        )
    }

    private func drawCurvePointsOnCanvas() {
        guard
            let drawingCurve,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        drawingToolRenderer?.drawCurve(
            drawingCurve,
            using: selectedLayerTexture,
            onDrawing: { [weak self] resultTexture in
                self?.updateCanvasView(realtimeDrawingTexture: resultTexture)
            },
            onCommandBufferCompleted: { [weak self] in
                // Reset parameters on drawing completion
                self?.resetAllInputParameters()

                self?.completeDrawing()
            }
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

    private func completeDrawing() {
        guard
            let layerId = textureLayers.selectedLayer?.id,
            let selectedLayerTexture = canvasRenderer.selectedLayerTexture
        else { return }

        undoDrawingDebouncer.scheduleAsync { [weak self] in
            do {
                try await self?.dependencies.textureRepository.updateTexture(
                    texture: selectedLayerTexture,
                    for: layerId
                )

                // Update `updatedAt` when drawing completes
                self?.projectMetaDataStorage.refreshUpdatedAt()

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

        canvasRenderer.updateCanvasView()
    }

    private func cancelFingerDrawing() {

        drawingToolRenderer?.clearTextures()

        fingerStroke.reset()

        drawingCurve = nil
        transforming.resetMatrix()

        canvasRenderer.resetCommandBuffer()

        canvasRenderer.updateCanvasView()
    }

    func updateCanvasView(realtimeDrawingTexture: MTLTexture? = nil) {
        guard
            let selectedLayer = textureLayers.selectedLayer
        else { return }

        canvasRenderer.updateCanvasView(
            realtimeDrawingTexture: realtimeDrawingTexture,
            selectedLayer: .init(item: selectedLayer)
        )
    }

    func updateCanvasByMergingAllLayers() {
        Task {
            // Set the texture of the selected texture layer to the renderer
            try await canvasRenderer.updateSelectedLayerTexture(
                textureLayers: textureLayers,
                textureRepository: dependencies.textureRepository
            )

            updateCanvasView()
        }
    }
}
