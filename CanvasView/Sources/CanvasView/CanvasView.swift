//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@preconcurrency import MetalKit

open class CanvasView: UIView {

    public var isDrawing: AnyPublisher<Bool, Never> {
        viewModel.isDrawing
    }

    public var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }
    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    /// A publisher that emits a request to show the alert
    public var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    public var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }
    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasView` setup completes
    public var setupCompletion: AnyPublisher<CanvasConfigurationResult, Never> {
        setupCompletionSubject.eraseToAnyPublisher()
    }
    private let setupCompletionSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    /// A publisher that emits `Void` when drawing completes
    public var drawingCompletion: AnyPublisher<Void, Never> {
        drawingCompletionSubject.eraseToAnyPublisher()
    }
    private let drawingCompletionSubject = PassthroughSubject<Void, Never>()

    public func thumbnail() -> UIImage? {
        viewModel.thumbnail()
    }

    /// The size of the texture currently set on the canvas
    public var currentTextureSize: CGSize {
        viewModel.currentTextureSize
    }

    /// The size of the screen
    public static var screenSize: CGSize {
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size
        return .init(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    @Published var textureLayersStorage: CoreDataTextureLayersStorage

    public static let thumbnailName: String = "thumbnail.png"

    /// The single Metal device instance used throughout the app
    private let sharedDevice: MTLDevice

    private let renderer: MTLRendering

    private let undoTextureLayers: UndoTextureLayers

    private let displayView: CanvasDisplayView

    private let drawingUndoManager = UndoManager()

    private let viewModel: CanvasViewModel

    private let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    private let undoTextureInMemoryRepository: UndoTextureInMemoryRepository

    private let textureLayersStorageController: PersistenceController

    private var cancellables = Set<AnyCancellable>()

    /// Fetches `textureLayers` data from Core Data, returns nil if an error occurs.
    private var textureLayersStateFromCoreDataEntity: TextureLayersState? {
        guard
            let entity = try? textureLayersStorage.fetch()
        else { return nil }
        return try? .init(entity: entity)
    }

    public init() {
        guard let sharedDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = sharedDevice
        self.renderer = MTLRenderer(device: sharedDevice)
        self.displayView = .init(renderer: renderer)
        do {
            self.textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                renderer: renderer
            )
        } catch {
            fatalError("Failed to initialize the canvas")
        }
        self.undoTextureInMemoryRepository = .init(
            renderer: renderer
        )
        self.textureLayersStorageController = .init(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )
        self.undoTextureLayers = .init(
            textureLayers: TextureLayers(
                renderer: renderer,
                repository: textureLayersDocumentsRepository
            ),
            renderer: renderer,
            inMemoryRepository: undoTextureInMemoryRepository
        )
        self.viewModel = .init(
            dependencies: .init(
                canvasRenderer: .init(
                    renderer: renderer,
                    repository: textureLayersDocumentsRepository,
                    displayView: displayView
                ),
                textureLayers: undoTextureLayers,
                textureLayersDocumentsRepository: textureLayersDocumentsRepository,
                undoTextureInMemoryRepository: undoTextureInMemoryRepository
            )
        )
        self.textureLayersStorage = .init(
            textureLayers: undoTextureLayers,
            context: textureLayersStorageController.viewContext
        )
        super.init(frame: .zero)
    }
    public required init?(coder: NSCoder) {
        guard let sharedDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = sharedDevice
        self.renderer = MTLRenderer(device: sharedDevice)
        self.displayView = .init(renderer: renderer)
        do {
            self.textureLayersDocumentsRepository = try TextureLayersDocumentsRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                renderer: renderer
            )
        } catch {
            fatalError("Failed to initialize the canvas")
        }
        self.undoTextureInMemoryRepository = .init(
            renderer: renderer
        )
        self.textureLayersStorageController = .init(
            xcdatamodeldName: "CanvasStorage",
            location: .swiftPackageManager
        )
        self.undoTextureLayers = .init(
            textureLayers: TextureLayers(
                renderer: renderer,
                repository: textureLayersDocumentsRepository
            ),
            renderer: renderer,
            inMemoryRepository: undoTextureInMemoryRepository
        )
        self.viewModel = .init(
            dependencies: .init(
                canvasRenderer: .init(
                    renderer: renderer,
                    repository: textureLayersDocumentsRepository,
                    displayView: displayView
                ),
                textureLayers: undoTextureLayers,
                textureLayersDocumentsRepository: textureLayersDocumentsRepository,
                undoTextureInMemoryRepository: undoTextureInMemoryRepository
            )
        )
        self.textureLayersStorage = .init(
            textureLayers: undoTextureLayers,
            context: textureLayersStorageController.viewContext
        )
        super.init(coder: coder)
    }

    public func setup(
        drawingRenderers: [DrawingRenderer],
        configuration: CanvasConfiguration
    ) async throws {

        // Set an initial value to prevent out-of-memory errors when no limit is applied
        drawingUndoManager.levelsOfUndo = 8

        layoutViews()
        addEvents()
        bindData()
        try await viewModel.setup(
            textureLayersState: textureLayersStateFromCoreDataEntity,
            drawingRenderers: CanvasViewModel.resolveDrawingRenderers(
                renderer: renderer,
                drawingRenderers: drawingRenderers
            ),
            configuration: configuration
        )
    }

    private func layoutViews() {
        addSubview(displayView)
        displayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            displayView.topAnchor.constraint(equalTo: topAnchor),
            displayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            displayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            displayView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func addEvents() {
        addGestureRecognizer(
            FingerInputGestureRecognizer(delegate: self)
        )
        addGestureRecognizer(
            PencilInputGestureRecognizer(delegate: self)
        )
    }

    private func bindData() {
        displayView.displayTextureSizeChanged
            .sink { [weak self] _ in
                self?.viewModel.onUpdateDisplayTexture()
            }
            .store(in: &cancellables)

        undoTextureLayers.didEmitUndoObjectPair
            .sink { [weak self] undoObjectPair in
                self?.registerUndoObjectPair(undoObjectPair)
            }
            .store(in: &cancellables)

        viewModel.setupCompletion
            .sink { [weak self] result in
                self?.viewModel.completeSetup(result: result)
                self?.setupCompletionSubject.send(result)
            }
            .store(in: &cancellables)

        viewModel.drawingCompletion
            .sink { [weak self] in
                self?.drawingCompletionSubject.send(())
            }
            .store(in: &cancellables)

        viewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertSubject.send(error)
            }
            .store(in: &cancellables)
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    public func newCanvas(
        textureSize: CGSize
    ) async throws {
        try await viewModel.newCanvas(
            textureSize: textureSize
        )
    }

    public func loadFiles(
        in workingDirectoryURL: URL
    ) async throws {
        // Load texture layer data from the JSON file
        let textureLayersArchiveModel: TextureLayersArchiveModel = try .init(
            in: workingDirectoryURL
        )
        let textureLayerState: TextureLayersState = try .init(model: textureLayersArchiveModel)

        try await viewModel.restoreCanvasFromDocumentsFolder(
            workingDirectoryURL: workingDirectoryURL,
            textureLayersState: textureLayerState
        )
    }

    public func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {
        try await viewModel.exportFiles(
            thumbnailLength: thumbnailLength,
            device: sharedDevice,
            to: workingDirectoryURL
        )
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingToolType: Int) {
        viewModel.setDrawingTool(drawingToolType)
    }

    public func undo() {
        drawingUndoManager.undo()
        didUndoSubject.send(
            .init(drawingUndoManager)
        )
    }
    public func redo() {
        drawingUndoManager.redo()
        didUndoSubject.send(
            .init(drawingUndoManager)
        )
    }
    func resetUndo() {
        undoTextureInMemoryRepository.removeAll()
        drawingUndoManager.removeAllActions()
        didUndoSubject.send(
            .init(drawingUndoManager)
        )
    }

    func registerUndoObjectPair(
        _ undoRedoObject: UndoRedoObjectPair
    ) {
        undoRedoObject.undoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? self.undoTextureInMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        undoRedoObject.redoObject.deinitSubject
            .sink(receiveValue: { [weak self] result in
                guard let `self`, let undoTextureId = result.undoTextureId else { return }
                // Do nothing if an error occurs, since nothing can be done
                try? self.undoTextureInMemoryRepository.removeTexture(
                    undoTextureId
                )
            })
            .store(in: &cancellables)

        drawingUndoManager.registerUndo(withTarget: self) { [weak self, undoRedoObject, undoTextureInMemoryRepository] _ in
            guard let `self` else { return }

            Task {
                do {
                    try await undoRedoObject.undoObject.applyUndo(
                        layers: self.undoTextureLayers.textureLayers,
                        repository: undoTextureInMemoryRepository
                    )
                } catch {
                    Logger.error(error)
                }
            }

            // Redo Registration
            self.registerUndoObjectPair(undoRedoObject.reversed())
        }

        didUndoSubject.send(
            .init(drawingUndoManager)
        )
    }
}

extension CanvasView: FingerInputGestureRecognizerSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        viewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view
        )
    }
}

extension CanvasView: PencilInputGestureRecognizerSender {

    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        viewModel.onPencilGestureDetected(
            estimatedTouches: touches,
            with: event,
            view: view
        )
    }

    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView) {
        viewModel.onPencilGestureDetected(
            actualTouches: touches,
            view: view
        )
    }
}
