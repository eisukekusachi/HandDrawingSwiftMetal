//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@objc public class CanvasView: UIView {

    private var drawingRenderers: [DrawingRenderer] = []

    public var isDrawing: AnyPublisher<Bool, Never> {
        canvasViewModel.isDrawing
    }

    public var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    public var alert: AnyPublisher<CanvasError, Never> {
        alertSubject.eraseToAnyPublisher()
    }
    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    /// A publisher that sends messages
    public var message: AnyPublisher<ToastMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    private let messageSubject = PassthroughSubject<ToastMessage, Never>()

    public var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `ResolvedTextureLayerArrayConfiguration` when the canvas view setup is completed
    public var didInitializeCanvasView: AnyPublisher<ResolvedTextureLayerArrayConfiguration, Never> {
        didInitializeCanvasViewSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `TextureLayersProtocol` when `TextureLayers` setup is prepared
    public var didInitializeTextures: AnyPublisher<any TextureLayersProtocol, Never> {
        didInitializeTexturesSubject.eraseToAnyPublisher()
    }

    public var zipFileURL: URL {
        canvasViewModel.zipFileURL
    }

    private let renderer: MTLRendering

    private let displayView = CanvasDisplayView()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let didInitializeCanvasViewSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    private let didInitializeTexturesSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private let canvasViewModel = CanvasViewModel()

    private var cancellables = Set<AnyCancellable>()

    public init() {
        renderer = MTLRenderer(device: displayView.device)

        super.init(frame: .zero)
        commonInitialize()
    }
    public required init?(coder: NSCoder) {
        renderer = MTLRenderer(device: displayView.device)

        super.init(coder: coder)
        commonInitialize()
    }

    public override func layoutSubviews() {
        canvasViewModel.frameSize = frame.size
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
        displayView.initialize(renderer: renderer)

        try await canvasViewModel.setup(
            drawingRenderers: drawingRenderers,
            dependencies: .init(
                renderer: renderer,
                displayView: displayView
            ),
            configuration: configuration
        )
    }

    public func newCanvas(configuration: TextureLayerArrayConfiguration) async throws {
        try await canvasViewModel.newCanvas(configuration: configuration)
    }

    public func loadFiles(
        in workingDirectoryURL: URL
    ) async throws {
        try await canvasViewModel.loadFiles(
            in: workingDirectoryURL
        )
    }
    public func exportFiles(
        thumbnailLength: CGFloat = CanvasViewModel.thumbnailLength,
        to workingDirectoryURL: URL
    ) async throws {
        try await canvasViewModel.exportFiles(
            thumbnailLength: thumbnailLength,
            to: workingDirectoryURL
        )
    }

    public func resetTransforming() {
        canvasViewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingToolType: Int) {
        canvasViewModel.setDrawingTool(drawingToolType)
    }

    public func undo() {
        canvasViewModel.undo()
    }
    public func redo() {
        canvasViewModel.redo()
    }
}

extension CanvasView {
    private func bindData() {
        displayView.displayTextureSizeChanged
            .sink { [weak self] displayTextureSize in
                self?.canvasViewModel.didChangeDisplayTextureSize(displayTextureSize)
            }
            .store(in: &cancellables)

        canvasViewModel.didInitializeCanvasView
            .sink { [weak self] value in
                self?.didInitializeCanvasViewSubject.send(value)
            }
            .store(in: &cancellables)

        canvasViewModel.didInitializeTextures
            .sink { [weak self] value in
                self?.didInitializeTexturesSubject.send(value)
            }
            .store(in: &cancellables)

        canvasViewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertSubject.send(error)
            }
            .store(in: &cancellables)

        canvasViewModel.message
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.messageSubject.send(message)
            }
            .store(in: &cancellables)

        canvasViewModel.didUndo
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
        canvasViewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view
        )
    }
}

extension CanvasView: PencilInputGestureRecognizerSender {

    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            estimatedTouches: touches,
            with: event,
            view: view
        )
    }

    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            actualTouches: touches,
            view: view
        )
    }
}
