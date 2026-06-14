//
//  CanvasView.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

@preconcurrency import MetalKit

open class CanvasView: UIView {

    public var thumbnail: UIImage? {
        canvasTexture?.uiImage?.resizeWithAspectRatio(
            height: 500,
            scale: 1.0
        )
    }

    /// Emits stroke events
    public var strokeEvents: AnyPublisher<StrokeEvent, Never> {
        strokeEventSubject.eraseToAnyPublisher()
    }
    private let strokeEventSubject = PassthroughSubject<StrokeEvent, Never>()

    /// Emits transform lifecycle
    public var transformLifecyclePhase: AnyPublisher<TransformLifecycle, Never> {
        viewModel.transformLifecyclePhase
    }

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

    private let fingerInputGestureRecognizer: FingerInputGestureRecognizer

    private let pencilInputGestureRecognizer: PencilInputGestureRecognizer

    public init(
        device: MTLDevice? = nil,
        configuration: CanvasConfiguration = .init()
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
        self.fingerInputGestureRecognizer = FingerInputGestureRecognizer()
        self.pencilInputGestureRecognizer = PencilInputGestureRecognizer()
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
        fingerInputGestureRecognizer.setDelegate(sender: self, delegate: self)
        pencilInputGestureRecognizer.setDelegate(sender: self, delegate: self)
        addGestureRecognizer(fingerInputGestureRecognizer)
        addGestureRecognizer(pencilInputGestureRecognizer)
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
    open func initializeCanvas(_ textureSize: CGSize) async throws {
        try await viewModel.initializeCanvas(textureSize)

        // Set an initial value, as nothing is rendered when the drawing renderer is empty
        if viewModel.drawingRenderer == nil {
            initializeDrawingRenderer(textureSize: textureSize)
        }

        // Display the initialized canvas immediately so the view does not remain
        // stale or blank until a later draw or display event occurs
        updateCanvasTextureUsingCurrentTexture()
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

    public func setDrawingRenderer(_ drawingRenderer: HighPrecisionDrawingRenderer) {
        viewModel.setDrawingRenderer(drawingRenderer)
    }

    public func resetTransforming() {
        viewModel.resetTransforming()
    }
}

extension CanvasView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === fingerInputGestureRecognizer ||
        gestureRecognizer === pencilInputGestureRecognizer ||
        otherGestureRecognizer === fingerInputGestureRecognizer ||
        otherGestureRecognizer === pencilInputGestureRecognizer
    }
}

extension CanvasView: FingerInputGestureRecognizerSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        guard viewModel.canvasTexture != nil else {
            Logger.error("Failed to access canvas texture because it has not been initialized. Call initializeCanvas(_:) first.")
            return
        }
        viewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view
        )
    }
}

extension CanvasView: PencilInputGestureRecognizerSender {

    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        guard viewModel.canvasTexture != nil else {
            Logger.error("Failed to access canvas texture because it has not been initialized. Call initializeCanvas(_:) first.")
            return
        }
        viewModel.onPencilGestureDetected(
            estimatedTouches: touches,
            with: event,
            view: view
        )
    }

    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView) {
        guard viewModel.canvasTexture != nil else {
            Logger.error("Failed to access canvas texture because it has not been initialized. Call initializeCanvas(_:) first.")
            return
        }
        viewModel.onPencilGestureDetected(
            actualTouches: touches,
            view: view
        )
    }
}

private extension CanvasView {
    func initializeDrawingRenderer(
        textureSize: CGSize
    ) {
        let drawingRenderer = BrushDrawingRenderer()
        drawingRenderer.setup(renderer: renderer)
        drawingRenderer.initializeTextures(textureSize)
        setDrawingRenderer(drawingRenderer)
    }
}
