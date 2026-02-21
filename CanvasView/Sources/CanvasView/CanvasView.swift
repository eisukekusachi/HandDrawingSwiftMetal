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

    /// Emits drawing-related events
    public var drawingEvent: AnyPublisher<DrawingEvent, Never> {
        drawingEventSubject.eraseToAnyPublisher()
    }
    private let drawingEventSubject = PassthroughSubject<DrawingEvent, Never>()

    /// A publisher that emits `CanvasConfigurationResult` when `CanvasView` setup completes
    public var setupCompletion: AnyPublisher<CanvasConfigurationResult, Never> {
        setupCompletionSubject.eraseToAnyPublisher()
    }
    private let setupCompletionSubject = PassthroughSubject<CanvasConfigurationResult, Never>()

    /// The single Metal device instance used throughout the app
    public let sharedDevice: MTLDevice

    public let renderer: MTLRendering

    public var cancellables = Set<AnyCancellable>()

    public var currentTexture: MTLTexture? {
        viewModel.currentTexture
    }

    public var realtimeDrawingTexture: MTLTexture? {
        viewModel.realtimeDrawingTexture
    }

    public var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    public var canvasTexture: MTLTexture? {
        canvasRenderer.canvasTexture
    }

    public var currentFrameCommandBuffer: MTLCommandBuffer? {
        displayView.currentFrameCommandBuffer
    }

    /// Display link for realtime drawing
    private var drawingDisplayLink = DrawingDisplayLink()

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
        textureSize: CGSize,
        configuration: CanvasConfiguration
    ) async throws {
        layoutViews()
        addEvents()
        bindData()

        try await viewModel.setup(
            textureSize: textureSize,
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
        viewModel.setupCompletion
            .sink { [weak self] result in
                guard let `self` else { return }
                self.viewModel.completeSetup(result: result)
                self.setupCompletionSubject.send(result)
            }
            .store(in: &cancellables)

        displayView.displayTextureSizeChanged
            .sink { [weak self] _ in
                Task {
                    try? await self?.updateCanvasTexture()
                    self?.drawCanvasToDisplay()
                }
            }
            .store(in: &cancellables)

        // The canvas is updated every frame during drawing
        drawingDisplayLink.update
            .sink { [weak self] in
                self?.viewModel.onDrawingDisplayLinkFrame()
            }
            .store(in: &cancellables)

        viewModel.drawingTouchPhase
            .sink { [weak self] touchPhase in
                self?.drawingDisplayLink.run(touchPhase)
            }
            .store(in: &cancellables)

        viewModel.drawingEvent
            .sink { [weak self] result in
                self?.drawingEventSubject.send(result)
            }
            .store(in: &cancellables)

        viewModel.currentTextureDisplaying
            .sink { [weak self] in
                Task {
                    try? await self?.updateCanvasTexture()
                    self?.drawCanvasToDisplay()
                }
            }
            .store(in: &cancellables)

        viewModel.realtimeDrawingTextureDisplaying
            .sink { [weak self] in
                self?.updateCanvasTextureUsingRealtimeDrawingTexture()
                self?.drawCanvasToDisplay()
            }
            .store(in: &cancellables)
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingRenderer: DrawingRenderer) {
        viewModel.setDrawingTool(drawingRenderer)
    }

    public func setCurrentTexture(_ texture: MTLTexture?) throws {
        try viewModel.setCurrentTexture(texture)
    }

    public func updateCanvas(_ textureSize: CGSize) async throws {
        try await viewModel.updateCanvas(textureSize)
    }

    open func updateCanvasTextureUsingRealtimeDrawingTexture() {
        viewModel.updateCanvasTextureUsingRealtimeDrawingTexture()
    }

    open func updateCanvasTexture() async throws {
        viewModel.updateCanvasTexture()
    }

    public func drawCanvasToDisplay() {
        viewModel.drawCanvasToDisplay()
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
