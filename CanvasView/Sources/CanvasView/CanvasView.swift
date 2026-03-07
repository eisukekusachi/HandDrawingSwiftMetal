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

    /// Emits stroke events
    public var strokeEvent: AnyPublisher<StrokeEvent, Never> {
        strokeEventSubject.eraseToAnyPublisher()
    }
    private let strokeEventSubject = PassthroughSubject<StrokeEvent, Never>()

    /// A publisher that emits `CGSize` when `CanvasView` setup completes
    public var canvasSizeDidChange: AnyPublisher<CGSize, Never> {
        canvasSizeDidChangeSubject.eraseToAnyPublisher()
    }
    private let canvasSizeDidChangeSubject = PassthroughSubject<CGSize, Never>()

    /// The single Metal device instance used throughout the app
    public let sharedDevice: MTLDevice

    public let renderer: MTLRendering

    public var canvasTexture: MTLTexture? {
        viewModel.canvasTexture
    }

    public var currentTexture: MTLTexture? {
        viewModel.currentTexture
    }

    public var realtimeDrawingTexture: MTLTexture? {
        viewModel.realtimeDrawingTexture
    }

    public var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    public var currentFrameCommandBuffer: MTLCommandBuffer? {
        displayView.currentFrameCommandBuffer
    }

    private let displayView: CanvasDisplayView

    private let viewModel: CanvasViewModel

    private let canvasRenderer: CanvasRenderer

    /// Display link for realtime drawing
    private var canvasDisplayLink = CanvasDisplayLink()

    private var cancellables = Set<AnyCancellable>()

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
            canvasRenderer: canvasRenderer
        )
        super.init(frame: .zero)
        layoutViews()
        addEvents()
        bindData()
    }
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        // Receives an event when displayTexture size changes.
        // Mainly used when the device rotates.
        displayView.displayTextureSizeChanged
            .sink { [weak self] _ in
                Task {
                    try? await self?.updateCanvasTextureUsingCurrentTexture()
                    self?.present()
                }
            }
            .store(in: &cancellables)

        // The canvas is updated every frame during drawing
        canvasDisplayLink.update
            .sink { [weak self] in
                self?.viewModel.onDrawingDisplayLinkFrame()
            }
            .store(in: &cancellables)

        // Receives an event when canvasTexture size changes
        viewModel.canvasSizeDidChangeSubject
            .sink { [weak self] textureSize in
                Task { [weak self] in
                    try? await self?.completeCanvasSizeChange(textureSize)
                    self?.canvasSizeDidChangeSubject.send(textureSize)
                }
            }
            .store(in: &cancellables)

        viewModel.drawingTouchPhaseSubject
            .sink { [weak self] touchPhase in
                self?.canvasDisplayLink.run(touchPhase)
            }
            .store(in: &cancellables)

        viewModel.strokeEventSubject
            .sink { [weak self] result in
                self?.strokeEventSubject.send(result)
            }
            .store(in: &cancellables)

        viewModel.currentTextureDisplayingSubject
            .sink { [weak self] in
                Task {
                    try? await self?.updateCanvasTextureUsingCurrentTexture()
                    self?.present()
                }
            }
            .store(in: &cancellables)

        viewModel.realtimeDrawingTextureDisplayingSubject
            .sink { [weak self] in
                self?.updateCanvasTextureUsingRealtimeDrawingTexture()
                self?.present()
            }
            .store(in: &cancellables)
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    public func setup(
        configuration: CanvasConfiguration? = nil
    ) throws {
        viewModel.setup(
            configuration: configuration ?? .init()
        )
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
    }

    public func setDrawingTool(_ drawingRenderer: DrawingRenderer) {
        viewModel.setDrawingTool(drawingRenderer)
    }

    public func setCurrentTexture(_ texture: MTLTexture?) throws {
        guard texture?.size == viewModel.currentTextureSize else {
            throw CanvasError.textureSizeMismatch
        }
        viewModel.setCurrentTexture(texture)
    }

    public func updateCanvasView(withNewTextureSize textureSize: CGSize) {
        viewModel.resizeCanvas(
            CanvasConfiguration.clampedTextureSize(textureSize)
        )
    }

    open func completeCanvasSizeChange(_ textureSize: CGSize) async throws {
        try await updateCanvasTextureUsingCurrentTexture()
        present()
    }

    open func updateCanvasTextureUsingRealtimeDrawingTexture() {
        viewModel.updateCanvasTextureUsingRealtimeDrawingTexture()
    }

    open func updateCanvasTextureUsingCurrentTexture() async throws {
        viewModel.updateCanvasTextureUsingCurrentTexture()
    }

    public func present() {
        viewModel.present()
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
