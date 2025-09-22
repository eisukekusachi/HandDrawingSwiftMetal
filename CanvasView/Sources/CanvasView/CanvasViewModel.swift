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
            canvasRenderer?.frameSize = frameSize
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

    /// A publisher that emits `ResolvedCanvasConfiguration` when the canvas view setup is completed
    var canvasViewSetupCompleted: AnyPublisher<ResolvedTextureLayerArrayConfiguration, Never> {
        canvasViewSetupCompletedSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `TextureLayers` when `TextureLayers` setup is prepared
    var textureLayersPrepared: AnyPublisher<any TextureLayersProtocol, Never> {
        textureLayersPreparedSubject.eraseToAnyPublisher()
    }

    private var dependencies: CanvasViewDependencies!

    private var projectMetaDataStorage: CoreDataProjectMetaDataStorage

    /// Maintains the state of the canvas
    private var textureLayersStorage: CoreDataTextureLayersStorage?

    /// Handles input from finger touches
    private let fingerStroke = FingerStroke()
    /// Handles input from Apple Pencil
    private let pencilStroke = PencilStroke()

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    /// A class that manages rendering to the canvas
    private var canvasRenderer: CanvasRenderer?

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

    private let alertSubject = PassthroughSubject<ErrorModel, Never>()

    private let toastSubject = PassthroughSubject<ToastModel, Never>()

    private let canvasViewSetupCompletedSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    private let textureLayersPreparedSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private var undoStack: UndoStack? = nil

    private let persistenceController: PersistenceController

    private var cancellables = Set<AnyCancellable>()

    init() {
        persistenceController = PersistenceController(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )

        projectMetaDataStorage = CoreDataProjectMetaDataStorage(
            project: ProjectMetaData(),
            context: persistenceController.viewContext
        )

        textureLayersStorage = CoreDataTextureLayersStorage(
            textureLayers: TextureLayers(),
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
            $0.configure(displayView: dependencies.displayView, renderer: dependencies.renderer)
        }
        self.drawingToolRenderers = drawingToolRenderers

        self.drawingToolRenderer = self.drawingToolRenderers[0]

        self.dependencies = dependencies

        self.canvasRenderer = CanvasRenderer(
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

        bindData()

        // Use the size from CoreData if available,
        // if not, use the size from the configuration
        Task {
            let configuration: TextureLayerArrayConfiguration = .init(entity: try? textureLayersStorage?.fetch()) ?? configuration.textureLayerArrayConfiguration

            // Initialize the texture repository
            let resolvedConfiguration = try await dependencies.textureRepository.initializeStorage(
                configuration: configuration,
                fallbackTextureSize: defaultTextureSize()
            )
            await setupCanvas(resolvedConfiguration)
        }
    }

    private func bindData() {
        // The canvas is updated every frame during drawing
        drawingDisplayLink.updatePublisher
            .sink { [weak self] in
                guard
                    let drawingCurve = self?.drawingCurve,
                    let texture = self?.canvasRenderer?.selectedTexture,
                    let selectedLayerId = self?.textureLayersStorage?.selectedLayer?.id
                else { return }

                self?.drawingToolRenderer?.drawCurve(
                    drawingCurve,
                    using: texture,
                    onDrawing: { [weak self] resultTexture in
                        self?.updateCanvasView(realtimeDrawingTexture: resultTexture)
                    },
                    onDrawingCompleted: { [weak self] resultTexture in
                        // Reset parameters on drawing completion
                        self?.resetAllInputParameters()
                    },
                    onCommandBufferCompleted: { [weak self] resultTexture in
                        self?.completeDrawing(texture: resultTexture, for: selectedLayerId)
                    }
                )
            }
            .store(in: &cancellables)

        // Update the canvas
        textureLayersStorage?.canvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasView()
            }
            .store(in: &cancellables)

        // Update the entire canvas, including all drawing textures
        textureLayersStorage?.fullCanvasUpdateRequestedPublisher
            .sink { [weak self] in
                self?.updateCanvasByMergingAllLayers()
            }
            .store(in: &cancellables)

        transforming.matrixPublisher
            .sink { [weak self] matrix in
                self?.canvasRenderer?.matrix = matrix
            }
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

    private func setupCanvas(_ configuration: ResolvedTextureLayerArrayConfiguration) async {
        guard let textureLayersStorage else { return }

        await textureLayersStorage.initialize(
            configuration: configuration,
            textureRepository: dependencies.textureRepository
        )

        canvasRenderer?.initTextures(textureSize: configuration.textureSize)

        canvasRenderer?.updateDrawingTextures(
            textureLayers: textureLayersStorage,
            textureRepository: dependencies.textureRepository
        ) { [weak self] in
            self?.completeCanvasSetup(configuration: configuration)
        }
    }

    private func completeCanvasSetup(configuration: ResolvedTextureLayerArrayConfiguration) {
        guard let textureLayersStorage else { return }

        for i in 0 ..< drawingToolRenderers.count {
            drawingToolRenderers[i].initTextures(configuration.textureSize)
        }

        undoStack?.initialize(configuration.textureSize)

        projectMetaDataStorage.refreshUpdatedAt()

        updateCanvasView()

        textureLayersPreparedSubject.send(textureLayersStorage)

        canvasViewSetupCompletedSubject.send(configuration)
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
        transforming.setMatrix(.identity)
        canvasRenderer?.updateCanvasView()
    }

    func setDrawingTool(_ drawingToolIndex: Int) {
        guard drawingToolIndex < drawingToolRenderers.count else { return }
        drawingToolRenderer = drawingToolRenderers[drawingToolIndex]
    }

    func newCanvas(configuration: TextureLayerArrayConfiguration) async throws {
        // Initialize the texture repository
        let resolvedConfiguration = try await dependencies.textureRepository.initializeStorage(
            configuration: configuration,
            fallbackTextureSize: defaultTextureSize()
        )
        await setupCanvas(resolvedConfiguration)

        transforming.setMatrix(.identity)

        projectMetaDataStorage.refresh()
    }

    func undo() {
        undoStack?.undo()
    }
    func redo() {
        undoStack?.redo()
    }

    func loadFile(
        zipFileURL: URL,
        optionalEntities: [AnyLocalFileLoader] = [],
        completion: ((ResolvedTextureLayerArrayConfiguration) -> Void)? = nil
    ) {
        Task {
            defer { activityIndicatorSubject.send(false) }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory
                try dependencies.localFileRepository.createWorkingDirectory()

                // Extract the zip file into the working directory
                let workingDirectoryURL = try await dependencies.localFileRepository.unzipToWorkingDirectoryAsync(
                    from: zipFileURL
                )

                // Restore the repository from the extracted textures
                let textureLayersModel: TextureLayersArchiveModel = try .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(TextureLayersArchiveModel.jsonFileName)
                )
                let textureLayersConfiguration: TextureLayerArrayConfiguration = .init(
                    textureSize: textureLayersModel.textureSize,
                    layerIndex: textureLayersModel.layerIndex,
                    layers: textureLayersModel.layers
                )
                let resolvedConfiguration: ResolvedTextureLayerArrayConfiguration = try await dependencies.textureRepository.restoreStorage(
                    from: workingDirectoryURL,
                    configuration: textureLayersConfiguration,
                    defaultTextureSize: defaultTextureSize()
                )
                await setupCanvas(resolvedConfiguration)

                // Restore the metadata
                let projectMetaData: ProjectMetaDataModel = try .init(
                    fileURL: workingDirectoryURL.appendingPathComponent(ProjectMetaDataModel.jsonFileName)
                )
                projectMetaDataStorage.update(
                    projectName: projectMetaData.projectName,
                    createdAt: projectMetaData.createdAt,
                    updatedAt: projectMetaData.updatedAt
                )

                // Restore data from externally configured entities
                for entity in optionalEntities {
                    try entity.load(in: workingDirectoryURL)
                }

                // Remove the working space
                dependencies.localFileRepository.removeWorkingDirectory()

                toastSubject.send(
                    .init(
                        title: "Success",
                        icon: UIImage(systemName: "hand.thumbsup.fill")
                    )
                )

                completion?(resolvedConfiguration)
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
        additionalItems: [AnyLocalFileNamedItem] = []
    ) {
        // Create a thumbnail image from the current canvas texture
        guard
            let textureLayersStorage,
            let canvasTexture = canvasRenderer?.canvasTexture,
            let thumbnailImage = canvasTexture.uiImage?.resizeWithAspectRatio(
                height: TextureLayersArchiveModel.thumbnailLength,
                scale: 1.0
            )
        else { return }

        Task {
            defer { activityIndicatorSubject.send(false) }
            activityIndicatorSubject.send(true)

            do {
                // Create a temporary working directory for saving project files
                try dependencies.localFileRepository.createWorkingDirectory()

                // Copy all textures from the textureRepository
                let textures = try await dependencies.textureRepository.copyTextures(
                    uuids: textureLayersStorage.layers.map { $0.id }
                )

                // Save the thumbnail image into the working directory
                async let resultCanvasThumbnail = try await dependencies.localFileRepository.saveItemToWorkingDirectory(
                    namedItem: .init(fileName: TextureLayersArchiveModel.thumbnailName, item: thumbnailImage)
                )

                // Save the textures into the working directory
                async let resultCanvasTextures = try await dependencies.localFileRepository.saveAllItemsToWorkingDirectory(
                    namedItems: textures.map {
                        .init(fileName: $0.uuid.uuidString, item: $0)
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
                    namedItem: ProjectMetaDataModel.namedItem(from: projectMetaDataStorage)
                )

                // Save an externally provided entities as JSON
                async let resultAdditional = try await dependencies.localFileRepository.saveAllItemsToWorkingDirectory(
                    namedItems: additionalItems
                )

                _ = try await (resultCanvasEntity, resultProjectMetaDataEntity, resultAdditional)

                // Zip the working directory into a single project file
                try dependencies.localFileRepository.zipWorkingDirectory(
                    to: zipFileURL(fileName: projectMetaDataStorage.projectName)
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
            let canvasRenderer,
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

        drawingDisplayLink.run(drawingCurve?.isCurrentlyDrawing ?? false)
    }

    private func transformCanvas() {
        guard let canvasRenderer else { return }

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
}

extension CanvasViewModel {

    private func cancelFingerDrawing() {

        drawingToolRenderer?.clearTextures()

        fingerStroke.reset()

        drawingCurve = nil
        transforming.resetMatrix()

        canvasRenderer?.resetCommandBuffer()

        canvasRenderer?.updateCanvasView()
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

        textureLayersStorage?.updateThumbnail(
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
        guard let textureLayersStorage else { return }

        canvasRenderer?.updateDrawingTextures(
            textureLayers: textureLayersStorage,
            textureRepository: dependencies.textureRepository
        ) { [weak self] in
            self?.updateCanvasView()
        }
    }

    func updateCanvasView(realtimeDrawingTexture: MTLTexture? = nil) {
        guard
            let selectedLayer = textureLayersStorage?.selectedLayer
        else { return }

        canvasRenderer?.updateCanvasView(
            realtimeDrawingTexture: realtimeDrawingTexture,
            selectedLayer: .init(item: selectedLayer)
        )
    }
}

extension CanvasViewModel {

    func zipFileURL(fileName: String) -> URL {
        FileManager.documentsFileURL(
            projectName: fileName,
            suffix: ProjectMetaData.fileSuffix
        )
    }
}
