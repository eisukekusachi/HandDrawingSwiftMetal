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

    /// Emits canvas events
    public var canvasEvents: AnyPublisher<CanvasEvent, Never> {
        canvasEventSubject.eraseToAnyPublisher()
    }
    private let canvasEventSubject = PassthroughSubject<CanvasEvent, Never>()

    /// Emits stroke events
    public var strokeEvents: AnyPublisher<StrokeEvent, Never> {
        strokeEventSubject.eraseToAnyPublisher()
    }
    private let strokeEventSubject = PassthroughSubject<StrokeEvent, Never>()

    public var canvasTexture: MTLTexture? {
        viewModel.canvasTexture
    }

    public var currentTexture: MTLTexture? {
        viewModel.currentTexture
    }

    public var realtimeDrawingTexture: MTLTexture? {
        viewModel.realtimeDrawingTexture
    }

    /// Command buffer for a single frame
    public var currentFrameCommandBuffer: MTLCommandBuffer? {
        displayView.currentFrameCommandBuffer
    }

    /// The single Metal device instance used throughout the app
    public let sharedDevice: MTLDevice

    /// Executes texture operations
    public let renderer: MTLRendering

    /// View that displays the canvas texture
    private let displayView: CanvasDisplayView

    /// Manages drawing onto the canvas texture and displays the result on the screen
    private let canvasRenderer: CanvasRenderer

    /// Display link for realtime drawing
    private var canvasDisplayLink = CanvasDisplayLink()

    private var cancellables = Set<AnyCancellable>()

    private let viewModel: CanvasViewModel

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

        // Subscribes to display texture size changes.
        // Mainly used when the device rotates.
        displayView.displayTextureSizeChanged
            .sink { [weak self] _ in
                self?.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        // Subscribes to canvas events
        viewModel.canvasEventSubject
            .sink { [weak self] event in
                switch event {
                case .canvasCreated(let textureSize):
                    Task { [weak self] in
                        await self?.completeCanvasCreation(textureSize)
                        self?.canvasEventSubject.send(
                            .canvasCreated(textureSize)
                        )
                    }
                case .displayCurrentTexture:
                    self?.updateCanvasTextureUsingCurrentTexture()
                case .displayRealtimeDrawingTexture:
                    self?.updateCanvasTextureUsingRealtimeDrawingTexture()
                }
            }
            .store(in: &cancellables)

        // Subscribes to stroke events
        viewModel.strokeEventSubject
            .sink { [weak self] result in
                self?.strokeEventSubject.send(result)
            }
            .store(in: &cancellables)

        // Subscribes to drawing touch phase updates
        viewModel.drawingTouchPhaseSubject
            .sink { [weak self] touchPhase in
                // Starts or stops the display link depending on the current touch phase
                self?.canvasDisplayLink.run(touchPhase)
            }
            .store(in: &cancellables)

        // Subscribes to the display link update
        canvasDisplayLink.update
            .sink { [weak self] in
                self?.viewModel.onDrawingDisplayLinkFrame()
            }
            .store(in: &cancellables)
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    /// Sets up the canvas using the specified configuration
    public func setup(
        _ configuration: CanvasConfiguration? = nil
    ) throws {
        try viewModel.setup(configuration ?? .init())
    }

    /// Creates the canvas using the specified texture size
    public func createCanvas(_ textureSize: CGSize) throws {
        try viewModel.createCanvas(
            CanvasConfiguration.clampedTextureSize(textureSize)
        )
    }

    /// Called after the canvas has been created
    open func completeCanvasCreation(_ textureSize: CGSize) async {
        viewModel.updateCanvasTexture(currentTexture)
        present()
    }

    open func updateCanvasTextureUsingRealtimeDrawingTexture() {
        viewModel.updateCanvasTexture(realtimeDrawingTexture)
        present()
    }

    open func updateCanvasTextureUsingCurrentTexture() {
        viewModel.updateCanvasTexture(currentTexture)
        present()
    }

    public func present() {
        viewModel.present()
    }
}

extension CanvasView {

    public func setCurrentTexture(_ texture: MTLTexture?) throws {
        guard texture?.size == viewModel.currentTextureSize else {
            throw CanvasError.textureSizeMismatch
        }
        viewModel.setCurrentTexture(texture)
    }

    public func setDrawingRenderer(_ drawingRenderer: DrawingRenderer) {
        viewModel.setDrawingRenderer(drawingRenderer)
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
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
