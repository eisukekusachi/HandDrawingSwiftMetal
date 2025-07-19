//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/16.
//

import Combine
import UIKit

class CanvasView: UIView {

    var displayTexture: MTLTexture? {
        displayView.displayTexture
    }

    /// A publisher that emits a request to show or hide the activity indicator
    var activityIndicator: AnyPublisher<Bool, Never> {
        activityIndicatorSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show the alert
    var alert: AnyPublisher<Error, Never> {
        alertSubject.eraseToAnyPublisher()
    }

    /// A publisher that emits a request to show or hide the toast
    var toast: AnyPublisher<ToastModel, Never> {
        toastSubject.eraseToAnyPublisher()
    }

    var undoRedoButtonState: AnyPublisher<UndoRedoButtonState, Never> {
        undoRedoButtonStateSubject.eraseToAnyPublisher()
    }

    var currentTextureSize: CGSize {
        canvasViewModel.currentTextureSize
    }

    var brushDiameter: Int {
        canvasViewModel.canvasState.brush.diameter
    }
    var eraserDiameter: Int {
        canvasViewModel.canvasState.eraser.diameter
    }

    var textureLayerConfiguration: TextureLayerConfiguration {
        canvasViewModel.textureLayerConfiguration
    }

    private let displayView = CanvasDisplayView()

    private let activityIndicatorSubject: PassthroughSubject<Bool, Never> = .init()

    private let alertSubject = PassthroughSubject<Error, Never>()

    private let toastSubject = PassthroughSubject<ToastModel, Never>()

    private var undoRedoButtonStateSubject = PassthroughSubject<UndoRedoButtonState, Never>()

    private let canvasViewModel = CanvasViewModel()

    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        canvasViewModel.frameSize = frame.size
    }

    func initialize(
        configuration: CanvasConfiguration
    ) {
        let scale = UIScreen.main.scale
        let size = UIScreen.main.bounds.size

        canvasViewModel.initialize(
            dependencies: .init(
                configuration: configuration
            ),
            configuration: configuration,
            defaultTextureSize: .init(
                width: size.width * scale,
                height: size.height * scale
            ),
            displayView: displayView
        )
    }

    func newCanvas(configuration: CanvasConfiguration) {
        canvasViewModel.newCanvas(configuration: configuration)
    }

    func resetTransforming() {
        canvasViewModel.resetTransforming()
    }

    func setDrawingTool(_ drawingTool: DrawingToolType) {
        canvasViewModel.setDrawingTool(drawingTool)
    }

    func setBrushColor(_ color: UIColor) {
        canvasViewModel.setBrushColor(color)
    }

    func setBrushDiameter(_ diameter: Float) {
        canvasViewModel.setBrushDiameter(diameter)
    }
    func setEraserDiameter(_ diameter: Float) {
        canvasViewModel.setEraserDiameter(diameter)
    }

    func saveFile() {
        canvasViewModel.saveFile()
    }
    func loadFile(zipFileURL: URL) {
        canvasViewModel.loadFile(zipFileURL: zipFileURL)
    }

    func undo() {
        canvasViewModel.undo()
    }
    func redo() {
        canvasViewModel.redo()
    }
}

extension CanvasView {

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

    private func bindData() {
        displayView.displayTextureSizeChanged
            .sink { [weak self] _ in
                self?.canvasViewModel.updateCanvasView()
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
            .sink { [weak self] value in
                self?.alertSubject.send(value)
            }
            .store(in: &cancellables)

        canvasViewModel.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.toastSubject.send(value)
            }
            .store(in: &cancellables)

        canvasViewModel.undoRedoButtonState
            .sink { [weak self] value in
                self?.undoRedoButtonStateSubject.send(value)
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
