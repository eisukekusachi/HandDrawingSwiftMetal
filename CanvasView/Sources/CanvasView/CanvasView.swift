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

    /// The single Metal device instance used throughout the app
    public let sharedDevice: MTLDevice

    public let renderer: MTLRendering

    public var cancellables = Set<AnyCancellable>()

    public var currentTexture: MTLTexture? {
        canvasRenderer.currentTexture
    }

    public var canvasTexture: MTLTexture? {
        canvasRenderer.canvasTexture
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

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasView` setup completes
    public var setupCompletion: AnyPublisher<CanvasConfigurationResult, Never> {
        setupCompletionSubject.eraseToAnyPublisher()
    }
    private let setupCompletionSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    public var fingerDrawingDidBegin: AnyPublisher<Void, Never> {
        fingerDrawingDidBeginSubject.eraseToAnyPublisher()
    }
    private let fingerDrawingDidBeginSubject = PassthroughSubject<Void, Never>()

    public var pencilDrawingDidBegin: AnyPublisher<Void, Never> {
        pencilDrawingDidBeginSubject.eraseToAnyPublisher()
    }
    private let pencilDrawingDidBeginSubject = PassthroughSubject<Void, Never>()

    /// A publisher that emits `MTLTexture?` when drawing completes
    public var drawingCompletion: AnyPublisher<MTLTexture?, Never> {
        drawingCompletionSubject.eraseToAnyPublisher()
    }
    private let drawingCompletionSubject = PassthroughSubject<MTLTexture?, Never>()

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

    public static let thumbnailName: String = "thumbnail.png"

    private let displayView: CanvasDisplayView

    private let viewModel: CanvasViewModel

    private let canvasRenderer: CanvasRenderer

    public init() {
        guard let sharedDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = sharedDevice
        self.renderer = MTLRenderer(device: sharedDevice)
        self.displayView = .init(renderer: renderer)

        self.canvasRenderer = .init(
            renderer: renderer,
            displayView: displayView
        )
        self.viewModel = .init(
            dependencies: .init(
                canvasRenderer: canvasRenderer
            )
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

        self.canvasRenderer = .init(
            renderer: renderer,
            displayView: displayView
        )
        self.viewModel = .init(
            dependencies: .init(
                canvasRenderer: self.canvasRenderer
            )
        )
        super.init(coder: coder)
    }

    public func setup(
        undoTextureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?,
        drawingRenderers: [DrawingRenderer],
        textureLayersState: TextureLayersState?,
        configuration: CanvasConfiguration
    ) async throws {
        guard !drawingRenderers.isEmpty else {
            fatalError("Drawing renderers must not be empty.")
        }

        layoutViews()
        addEvents()
        bindData()
        try await viewModel.setup(
            textureLayers: undoTextureLayers,
            textureLayersDocumentsRepository: textureLayersDocumentsRepository,
            textureLayersState: textureLayersState,
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

        viewModel.setupCompletion
            .sink { [weak self] result in
                self?.viewModel.completeSetup(result: result)
                self?.setupCompletionSubject.send(result)
            }
            .store(in: &cancellables)

        viewModel.fingerDrawingDidBegin
            .sink { [weak self] in
                self?.fingerDrawingDidBeginSubject.send(())
            }
            .store(in: &cancellables)

        viewModel.pencilDrawingDidBegin
            .sink { [weak self] in
                self?.pencilDrawingDidBeginSubject.send(())
            }
            .store(in: &cancellables)

        viewModel.drawingCompletion
            .sink { [weak self] result in
                self?.drawingCompletionSubject.send(result)
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

    open func newCanvas(
        textureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?
    ) async throws {
        try await viewModel.setupCanvas(
            textureLayers: textureLayers,
            textureLayersDocumentsRepository: textureLayersDocumentsRepository
        )
        viewModel.resetTransforming()
    }

    public func restoreCanvas(
        textureLayers: UndoTextureLayers,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?
    ) async throws {
        try await viewModel.setupCanvas(
            textureLayers: textureLayers,
            textureLayersDocumentsRepository: textureLayersDocumentsRepository
        )
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingRenderer: DrawingRenderer) {
        viewModel.setDrawingTool(drawingRenderer)
    }

    public func updateCurrentTexture(_ texture: MTLTexture?) {
        viewModel.updateCurrentTexture(texture)
    }

    public func updateCurrentTextureUsingRepository(
        textureLayers: UndoTextureLayers?,
        textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol?
    ) {
        viewModel.updateCurrentTextureUsingRepository(
            textureLayers: textureLayers,
            textureLayersDocumentsRepository: textureLayersDocumentsRepository
        )
    }

    public func refreshCanvas() {
        viewModel.refreshCanvas()
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
