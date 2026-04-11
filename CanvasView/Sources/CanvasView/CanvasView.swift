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

    /// The single Metal command queue instance used throughout the app
    public let sharedCommandQueue: MTLCommandQueue

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

    private let onCompleted: ((CGSize) -> Void)?

    public init(
        device: MTLDevice? = nil,
        configuration: CanvasConfiguration = .init(),
        onCompleted: ((CGSize) -> Void)? = nil
    ) {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        self.sharedDevice = device ?? defaultDevice
        guard let commandQueue = sharedDevice.makeCommandQueue() else {
            fatalError("Failed to create command queue.")
        }
        self.sharedCommandQueue = commandQueue
        self.renderer = MTLRenderer(
            device: sharedDevice,
            commandQueue: commandQueue
        )
        self.displayView = .init(
            device: sharedDevice,
            commandQueue: commandQueue
        )
        self.canvasRenderer = .init(
            renderer: renderer,
            displayView: displayView,
            backgroundColor: configuration.backgroundColor,
            baseBackgroundColor: configuration.baseBackgroundColor
        )
        self.viewModel = .init(
            canvasRenderer: canvasRenderer,
            configuration: configuration
        )
        self.onCompleted = onCompleted
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
                        guard let `self` else { return }
                        self.viewModel.onCompleteCanvasCreation(
                            renderer: self.renderer,
                            textureSize: textureSize
                        )
                        await self.completeCanvasCreation(textureSize)
                        self.onCompleted?(textureSize)
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

    /// Creates the canvas using the specified texture size
    public func initializeCanvas(_ textureSize: CGSize) async throws {
        try await viewModel.initializeCanvas(
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
