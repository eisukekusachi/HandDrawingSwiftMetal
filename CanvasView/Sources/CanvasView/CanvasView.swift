//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@objc public class CanvasView: UIView {

    /// A name of the file to be saved
    private(set) var projectName: String = Calendar.currentDate

    private var drawingRenderers: [DrawingToolRenderer] = []

    public var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    /// A publisher that emits a request to show or hide the activity indicator
    public var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    public var alert: AnyPublisher<ErrorModel, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    public var toast: AnyPublisher<ToastModel, Never> {
        toastSubject.eraseToAnyPublisher()
    }

    public var didUndo: AnyPublisher<UndoRedoButtonState, Never> {
        didUndoSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits `CanvasConfiguration` when the canvas view setup is completed
    public var canvasViewSetupCompleted: AnyPublisher<ResolvedCanvasConfiguration, Never> {
        canvasViewSetupCompletedSubject.eraseToAnyPublisher()
    }

    public var textureLayerConfiguration: TextureLayerConfiguration {
        canvasViewModel.textureLayerConfiguration
    }

    private var renderer: MTLRendering

    private let displayView = CanvasDisplayView()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<ErrorModel, Never>()

    private let toastSubject = PassthroughSubject<ToastModel, Never>()

    private let canvasViewSetupCompletedSubject = PassthroughSubject<ResolvedCanvasConfiguration, Never>()

    private var didUndoSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private let canvasViewModel = CanvasViewModel()

    private var cancellables = Set<AnyCancellable>()

    public init() {

        renderer = MTLRenderer(device: displayView.device)

        super.init(frame: .zero)

        setup()
    }
    public required init?(coder: NSCoder) {

        renderer = MTLRenderer(device: displayView.device)

        super.init(coder: coder)

        setup()
    }

    public override func layoutSubviews() {
        canvasViewModel.frameSize = frame.size
    }

    private func setup() {
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
        configuration: ProjectConfiguration
    ) {
        displayView.configure(renderer: renderer)

        canvasViewModel.initialize(
            drawingToolRenderers: drawingToolRenderers,
            dependencies: .init(
                renderer: renderer,
                displayView: displayView
            ),
            configuration: configuration
        )
    }

    public func newCanvas(configuration: CanvasConfiguration) {
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
            projectName: projectName,
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
        ) { [weak self] configuration in
            self?.projectName = configuration.projectName
        }
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

        canvasViewModel.canvasViewSetupCompleted
            .sink { [weak self] value in
                self?.canvasViewSetupCompletedSubject.send(value)
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
