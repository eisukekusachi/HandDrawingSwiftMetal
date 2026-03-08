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
                self?.updateCanvasTextureUsingCurrentTexture()
            }
            .store(in: &cancellables)

        viewModel.strokeEventSubject
            .sink { [weak self] result in
                self?.strokeEventSubject.send(result)
            }
            .store(in: &cancellables)

        viewModel.canvasEventSubject
            .sink { [weak self] event in
                switch event {
                case .canvasCreated(let textureSize):
                    self?.completeCanvasCreation(textureSize)
                    self?.canvasEventSubject.send(
                        .canvasCreated(textureSize)
                    )
                case .displayCurrentTexture:
                    self?.updateCanvasTextureUsingCurrentTexture()
                case .displayRealtimeDrawingTexture:
                    self?.updateCanvasTextureUsingRealtimeDrawingTexture()
                }
            }
            .store(in: &cancellables)

        viewModel.drawingTouchPhaseSubject
            .sink { [weak self] touchPhase in
                self?.canvasDisplayLink.run(touchPhase)
            }
            .store(in: &cancellables)

        // The canvas is updated every frame during drawing
        canvasDisplayLink.update
            .sink { [weak self] in
                self?.viewModel.onDrawingDisplayLinkFrame()
            }
            .store(in: &cancellables)
    }

    public override func layoutSubviews() {
        viewModel.frameSize = frame.size
    }

    public func setup(
        _ configuration: CanvasConfiguration? = nil
    ) throws {
        viewModel.setup(configuration ?? .init())
    }

    public func createCanvas(_ textureSize: CGSize) {
        viewModel.createCanvas(
            CanvasConfiguration.clampedTextureSize(textureSize)
        )
    }

    open func completeCanvasCreation(_ textureSize: CGSize) {
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
