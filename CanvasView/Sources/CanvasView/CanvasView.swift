//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@objc public class CanvasView: UIView {

    private var drawingRenderers: [DrawingToolRenderer] = []

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

    /// A publisher that emits a request to show or hide the toast
    public var toast: AnyPublisher<CanvasMessage, Never> {
        toastSubject.eraseToAnyPublisher()
    }

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

    private let renderer: MTLRendering

    private let displayView = CanvasDisplayView()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<CanvasError, Never>()

    private let toastSubject = PassthroughSubject<CanvasMessage, Never>()

    private let didInitializeCanvasViewSubject = PassthroughSubject<ResolvedTextureLayerArrayConfiguration, Never>()

    private let didInitializeTexturesSubject = PassthroughSubject<any TextureLayersProtocol, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private let canvasViewModel = CanvasViewModel()

    private var cancellables = Set<AnyCancellable>()

    public init() {

        renderer = MTLRenderer(device: displayView.device ?? MTLCreateSystemDefaultDevice()!)

        super.init(frame: .zero)

        initialize()
    }
    public required init?(coder: NSCoder) {

        renderer = MTLRenderer(device: displayView.device ?? MTLCreateSystemDefaultDevice()!)

        super.init(coder: coder)

        initialize()
    }

    public override func layoutSubviews() {
        canvasViewModel.frameSize = frame.size
    }

    private func initialize() {
        layoutView()
        bindData()

        addGestureRecognizer(
            FingerInputGestureRecognizer(delegate: self)
        )
        addGestureRecognizer(
            PencilInputGestureRecognizer(delegate: self)
        )
    }

    public func initialize(
        drawingToolRenderers: [DrawingToolRenderer],
        configuration: CanvasConfiguration
    ) {
        displayView.initialize(renderer: renderer)

        canvasViewModel.initialize(
            drawingToolRenderers: drawingToolRenderers,
            dependencies: .init(
                renderer: renderer,
                displayView: displayView
            ),
            configuration: configuration
        )
    }

    public func newCanvas(configuration: TextureLayerArrayConfiguration) {
        Task {
            defer { activityIndicatorSubject.send(false) }
            activityIndicatorSubject.send(true)

            try await canvasViewModel.newCanvas(configuration: configuration)
        }
    }

    public func resetTransforming() {
        canvasViewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingToolType: Int) {
        canvasViewModel.setDrawingTool(drawingToolType)
    }

    public func saveFile(additionalItems: [AnyLocalFileNamedItem] = []) {
        canvasViewModel.saveFile(
            additionalItems: additionalItems
        )
    }
    public func loadFile(
        zipFileURL: URL,
        optionalEntities: [AnyLocalFileLoader] = []
    ) {
        canvasViewModel.loadFile(
            zipFileURL: zipFileURL,
            optionalEntities: optionalEntities
        )
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
            .sink { [weak self] _ in
                self?.canvasViewModel.updateCanvasView()
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

        canvasViewModel.activityIndicator
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.activityIndicatorSubject.send(value)
            }
            .store(in: &cancellables)

        canvasViewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertSubject.send(error)
            }
            .store(in: &cancellables)

        canvasViewModel.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.toastSubject.send(value)
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
