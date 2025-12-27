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

    /// A publisher that emits `TextureLayersProtocol` when `CanvasView` setup completes
    public var didInitialize: AnyPublisher<ResultConfiguration, Never> {
        didInitializeSubject.eraseToAnyPublisher()
    }
    private let didInitializeSubject = PassthroughSubject<ResultConfiguration, Never>()

    public var zipFileURL: URL {
        viewModel.zipFileURL
    }

    static var defaultTextureSize: CGSize {
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size
        return .init(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    /// The single Metal device instance used throughout the app
    private let sharedDevice: MTLDevice

    private let renderer: MTLRendering

    private let displayView: CanvasDisplayView

    private let viewModel: CanvasViewModel

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
        configuration: CanvasConfiguration,
        drawingRenderers: [DrawingRenderer]
    ) async throws {
        try await viewModel.setup(
            configuration: configuration,
            dependencies: .init(
                renderer: renderer,
                displayView: displayView
            ),
            drawingRenderers: drawingRenderers
        )
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    public func onTapNewCanvas(
        newProjectName: String,
        newTextureSize: CGSize
    ) async throws {
        try await viewModel.onTapNewCanvas(
            newProjectName: newProjectName,
            newTextureSize: newTextureSize
        )
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
    private func bindData() {
        displayView.displayTextureSizeChanged
            .sink { [weak self] displayTextureSize in
                self?.viewModel.didChangeDisplayTextureSize(displayTextureSize)
            }
            .store(in: &cancellables)

        viewModel.didInitialize
            .sink { [weak self] value in
                self?.didInitializeSubject.send(value)
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
