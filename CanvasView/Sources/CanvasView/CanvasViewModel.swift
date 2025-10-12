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

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    var toast: AnyPublisher<CanvasMessage, Never> {
        toastSubject.eraseToAnyPublisher()
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

    /// Texture layers stored in Core Data
    private var textureLayersStorage: CoreDataTextureLayersStorage

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

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    private let toastSubject = PassthroughSubject<CanvasMessage, Never>()

    /// Emit `TextureLayersProtocol` when the texture update is completed
    private let didInitializeTexturesSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    /// Emit `ResolvedTextureLayerArrayConfiguration` when the canvas view update is completed
    private let didInitializeCanvasViewSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private let undoTextureLayers: UndoTextureLayers

    private var cancellables = Set<AnyCancellable>()

    init() {
        canvasRenderer = CanvasRenderer()

        undoTextureLayers = UndoTextureLayers(
            textureLayers: TextureLayers()
        )

        persistenceController = PersistenceController(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )

        projectMetaDataStorage = CoreDataProjectMetaDataStorage(
            project: ProjectMetaData(),
            context: persistenceController.viewContext
        )

        textureLayersStorage = CoreDataTextureLayersStorage(
            textureLayers: undoTextureLayers,
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
    ) {
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
            self.undoTextureLayers.initialize(
                undoTextureRepository: undoTextureRepository
            )
        }

        bindData()

        // Use the size from CoreData if available,
        // if not, use the size from the configuration
        Task {
            let textureLayersConfiguration: TextureLayerArrayConfiguration = .init(
                entity: try? textureLayersStorage.fetch()
            ) ?? configuration.textureLayerArrayConfiguration

            // Initialize the texture repository
            let resolvedTextureLayersConfiguration = try await dependencies.textureRepository.initializeStorage(
                configuration: textureLayersConfiguration,
                fallbackTextureSize: TextureLayerModel.defaultTextureSize()
            )
            await initializeTextures(resolvedTextureLayersConfiguration)
        }
    }

    func updateCanvasView(realtimeDrawingTexture: MTLTexture? = nil) {
        guard
            let selectedLayer = textureLayersStorage.selectedLayer
        else { return }

        canvasRenderer.updateCanvasView(
            realtimeDrawingTexture: realtimeDrawingTexture,
            selectedLayer: .init(item: selectedLayer)
        )
    }

    func updateCanvasByMergingAllLayers() {
        canvasRenderer.updateDrawingTextures(
            textureLayers: textureLayersStorage,
            textureRepository: dependencies.textureRepository
        ) { [weak self] in
            self?.updateCanvasView()
        }
    }
}

public extension CanvasViewModel {

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.updatePublisher
            .sink { [weak self] in
                self?.drawCurvePointsOnCanvas()
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayersStorage.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasView()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayersStorage.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasByMergingAllLayers()
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer.matrix = matrix
            }
            .store(in: &cancellables)

        undoTextureLayers.didUndo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.didUndoSubject.send(state)
            }
            .store(in: &cancellables)
    }

    private func initializeTextures(_ configuration: ResolvedTextureLayerArrayConfiguration) async {
        // Initialize the textures used in the texture layers
        await textureLayersStorage.initialize(
            configuration: configuration,
            textureRepository: dependencies.textureRepository
        )

        // Initialize the repository used for Undo
        undoTextureLayers.initializeStorage(
            configuration.textureSize,
            canvasRenderer: canvasRenderer
        )

        // Initialize the textures used in the drawing tool
        for i in 0 ..< drawingToolRenderers.count {
            drawingToolRenderers[i].initializeTextures(configuration.textureSize)
        }

        // Initialize the textures used in the renderer
        canvasRenderer.initializeTextures(
            textureSize: configuration.textureSize
        )

        // Update the canvas view
        canvasRenderer.updateDrawingTextures(
            textureLayers: textureLayersStorage,
            textureRepository: dependencies.textureRepository
        ) { [weak self] in
            guard let `self` else { return }
            self.updateCanvasView()

            self.didInitializeTexturesSubject.send(self.textureLayersStorage)
            self.didInitializeCanvasViewSubject.send(configuration)

            // Update to the latest date
            self.projectMetaDataStorage.refreshUpdatedAt()
        }
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
                    await undoTextureLayers.setDrawingUndoObject()
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
                await undoTextureLayers.setDrawingUndoObject()
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
        await initializeTextures(resolvedConfiguration)

        transforming.setMatrix(.identity)

        projectMetaDataStorage.refresh()
    }

    func undo() {
        undoTextureLayers.undo()
    }
    func redo() {
        undoTextureLayers.redo()
    }

    func loadFile(
        zipFileURL: URL,
        optionalEntities: [AnyLocalFileLoader] = [],
        completion: ((ResolvedTextureLayerArrayConfiguration) -> Void)? = nil
    ) {
        Task {
            defer {
                // Remove the working space
                dependencies.localFileRepository.removeWorkingDirectory()

                activityIndicatorSubject.send(false)
            }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory
                try dependencies.localFileRepository.createWorkingDirectory()

                // Extract the zip file into the working directory
                let workingDirectoryURL = try await dependencies.localFileRepository.unzipToWorkingDirectoryAsync(
                    from: zipFileURL
                )

                // Load texture layer data from the JSON file
                let textureLayersModel: TextureLayersArchiveModel = try .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(TextureLayersArchiveModel.jsonFileName)
                )
                let textureLayersConfiguration: TextureLayerArrayConfiguration = .init(
                    textureSize: textureLayersModel.textureSize,
                    layerIndex: textureLayersModel.layerIndex,
                    layers: textureLayersModel.layers
                )

                let resolvedTextureLayersConfiguration: ResolvedTextureLayerArrayConfiguration = try await dependencies.textureRepository.restoreStorage(
                    from: workingDirectoryURL,
                    configuration: textureLayersConfiguration,
                    defaultTextureSize: TextureLayerModel.defaultTextureSize()
                )

                // Load project metadata, falling back if it is missing
                let projectMetaData: ProjectMetaDataArchiveModel? = try? .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(ProjectMetaDataArchiveModel.jsonFileName)
                )

                // Restore the textures
                await initializeTextures(resolvedTextureLayersConfiguration)

                // Update metadata
                projectMetaDataStorage.update(
                    projectName: projectMetaData?.projectName ?? zipFileURL.fileName,
                    createdAt: projectMetaData?.createdAt ?? Date(),
                    updatedAt: projectMetaData?.updatedAt ?? Date()
                )

                // Restore data from externally configured entities
                for entity in optionalEntities {
                    entity.loadIgnoringError(in: workingDirectoryURL)
                }

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )

                completion?(resolvedTextureLayersConfiguration)
            }
            catch {
                alertSubject.send(
                    CanvasError.create(
                        error as NSError,
                        title: String(localized: "Loading Error", bundle: .module)
                    )
                )
            }
        }
    }

    func saveFile(
        additionalItems: [AnyLocalFileNamedItem] = []
    ) {
        // Create a thumbnail image from the current canvas texture
        guard
            let thumbnailImage = canvasRenderer.canvasTexture?.uiImage?.resizeWithAspectRatio(
                height: TextureLayersArchiveModel.thumbnailLength,
                scale: 1.0
            )
        else { return }

        Task {
            defer {
                /// Remove the working space
                dependencies.localFileRepository.removeWorkingDirectory()

                activityIndicatorSubject.send(false)
            }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory for saving project files
                try dependencies.localFileRepository.createWorkingDirectory()

                // Copy all textures from the textureRepository
                let textures = try await dependencies.textureRepository.duplicatedTextures(
                    textureLayersStorage.layers.map { $0.id }
                )

                // Save the thumbnail image into the working directory
                async let resultCanvasThumbnail = try await dependencies.localFileRepository.saveItemToWorkingDirectory(
                    namedItem: .init(fileName: TextureLayersArchiveModel.thumbnailName, item: thumbnailImage)
                )

                // Save the textures into the working directory
                async let resultCanvasTextures = try await dependencies.localFileRepository.saveAllItemsToWorkingDirectory(
                    namedItems: textures.map {
                        .init(fileName: $0.id.uuidString, item: $0)
                    }
                )
                _ = try await (resultCanvasThumbnail, resultCanvasTextures)

                // Save the texture layers as JSON
                let textureLayersModel: TextureLayersArchiveModel = .init(textureLayers: textureLayersStorage)
                async let resultCanvasEntity = try await dependencies.localFileRepository.saveItemToWorkingDirectory(
                    namedItem: textureLayersModel.namedItem()
                )

                // Save the project metadata as JSON
                async let resultProjectMetaDataEntity = try await dependencies.localFileRepository.saveItemToWorkingDirectory(
                    namedItem: ProjectMetaDataArchiveModel.namedItem(from: projectMetaDataStorage)
                )

                // Save an externally provided entities as JSON
                async let resultAdditional = try await dependencies.localFileRepository.saveAllItemsToWorkingDirectory(
                    namedItems: additionalItems
                )

                _ = try await (resultCanvasEntity, resultProjectMetaDataEntity, resultAdditional)

                // Zip the working directory into a single project file
                try dependencies.localFileRepository.zipWorkingDirectory(
                    to: projectMetaDataStorage.zipFileURL
                )

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )
            } catch {
                alertSubject.send(
                    CanvasError.create(
                        error as NSError,
                        title: String(localized: "Saving Error", bundle: .module)
                    )
                )
            }
        }
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
            let texture = canvasRenderer.selectedTexture,
            let selectedLayerId = textureLayersStorage.selectedLayer?.id
        else { return }

        drawingToolRenderer?.drawCurve(
            drawingCurve,
            using: texture,
            onDrawing: { [weak self] resultTexture in
                self?.updateCanvasView(realtimeDrawingTexture: resultTexture)
            },
            onCommandBufferCompleted: { [weak self] resultTexture in
                // Reset parameters on drawing completion
                self?.resetAllInputParameters()

                self?.completeDrawing(texture: resultTexture, layerId: selectedLayerId)
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

    private func completeDrawing(texture: MTLTexture, layerId: LayerId) {
        Task {
            do {
                try await dependencies.textureRepository.updateTexture(
                    texture: texture,
                    for: layerId
                )

                // Update `updatedAt` when drawing completes
                projectMetaDataStorage.refreshUpdatedAt()

                Task(priority: .background) {
                    await undoTextureLayers.pushUndoDrawingObject(
                        texture: texture
                    )
                }
            } catch {
                // No action on error
                Logger.error(error)
            }

            textureLayersStorage.updateThumbnail(layerId, texture: texture)
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
}
