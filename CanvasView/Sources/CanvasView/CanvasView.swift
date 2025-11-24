//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@preconcurrency import MetalKit

@objc public class CanvasView: UIView {

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

    /// A publisher that emits `ResolvedTextureLayerArrayConfiguration` when the canvas view setup is completed
    public var didInitializeCanvasView: AnyPublisher<ResolvedTextureLayerArrayConfiguration, Never> {
        didInitializeCanvasViewSubject.eraseToAnyPublisher()
    }
    private let didInitializeCanvasViewSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    /// A publisher that emits `TextureLayersProtocol` when `TextureLayers` setup is prepared
    public var didInitializeTextures: AnyPublisher<any TextureLayersProtocol, Never> {
        didInitializeTexturesSubject.eraseToAnyPublisher()
    }
    private let didInitializeTexturesSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    public var zipFileURL: URL {
        viewModel.zipFileURL
    }

    /// The single Metal device instance used throughout the app
    private let sharedDevice: MTLDevice

    private let renderer: MTLRendering

    private let displayView: CanvasDisplayView

    private let viewModel: CanvasViewModel

    private var drawingRenderers: [DrawingRenderer] = []

    private var cancellables = Set<AnyCancellable>()

    public init() {
        guard let sharedDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = sharedDevice

        renderer = MTLRenderer(device: sharedDevice)
        displayView = CanvasDisplayView(renderer: renderer)
        viewModel = CanvasViewModel(renderer: renderer)

        super.init(frame: .zero)
        commonInitialize()
    }
    public required init?(coder: NSCoder) {
        guard let sharedDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = sharedDevice

        renderer = MTLRenderer(device: sharedDevice)
        displayView = CanvasDisplayView(renderer: renderer)
        viewModel = CanvasViewModel(renderer: renderer)

        super.init(coder: coder)
        commonInitialize()
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    private func commonInitialize() {
        layoutView()
        bindData()

        addGestureRecognizer(
            FingerInputGestureRecognizer(delegate: self)
        )
        addGestureRecognizer(
            PencilInputGestureRecognizer(delegate: self)
        )
    }

    public func setup(
        drawingRenderers: [DrawingRenderer],
        configuration: CanvasConfiguration
    ) async throws {
        try await viewModel.setup(
            drawingRenderers: drawingRenderers,
            dependencies: .init(
                renderer: renderer,
                displayView: displayView
            ),
            configuration: configuration
        )
    }

    public func newCanvas(configuration: TextureLayerArrayConfiguration) async throws {
        try await viewModel.newCanvas(configuration: configuration)
    }

    public func loadFiles(
        in workingDirectoryURL: URL
    ) async throws {
        try await viewModel.loadFiles(
            in: workingDirectoryURL
        )
    }
    public func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {
        try await viewModel.exportFiles(
            thumbnailLength: thumbnailLength,
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
        viewModel.undo()
    }
    public func redo() {
        viewModel.redo()
    }
}

extension CanvasView {
    private func bindData() {
        displayView.displayTextureSizeChanged
            .sink { [weak self] displayTextureSize in
                self?.viewModel.didChangeDisplayTextureSize(displayTextureSize)
            }
            .store(in: &cancellables)

        viewModel.didInitializeCanvasView
            .sink { [weak self] value in
                self?.didInitializeCanvasViewSubject.send(value)
            }
            .store(in: &cancellables)

        viewModel.didInitializeTextures
            .sink { [weak self] value in
                self?.didInitializeTexturesSubject.send(value)
            }
            .store(in: &cancellables)

        viewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertSubject.send(error)
            }
            .store(in: &cancellables)

        viewModel.didUndo
            .sink { [weak self] value in
                self?.didUndoSubject.send(value)
            }
            .store(in: &cancellables)
    }

    private func layoutView() {
        addSubview(displayView)
        displayView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            displayView.topAnchor.constraint(equalTo: topAnchor),
            displayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            displayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            displayView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
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
