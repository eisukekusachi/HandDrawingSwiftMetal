//
//  ContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class ContentView: UIView {

    @IBOutlet weak var canvasView: CanvasView!

    @IBOutlet weak var topStackView: UIStackView!
    @IBOutlet weak var resetTransformButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var layerButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var exportImageButton: UIButton!
    @IBOutlet weak var newButton: UIButton!

    @IBOutlet weak var diameterSlider: UISlider!

    @IBOutlet weak var blackColorButton: UIButton!
    @IBOutlet weak var redColorButton: UIButton!
    @IBOutlet weak var eraserButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapResetTransformButton: (() -> Void)?
    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    var tapUndoButton: (() -> Void)?
    var tapRedoButton: (() -> Void)?

    var isDisplayLinkPaused: Bool = false {
        didSet {
            displayLink?.isPaused = isDisplayLinkPaused
        }
    }

    private var displayLink: CADisplayLink?

    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        instantiateNib()
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        instantiateNib()
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .white

        diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))

        // Configure the display link for rendering.
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
    }

}

extension ContentView {

    func bindTransforming(_ transforming: TransformingProtocol) {
        bindModels(transforming)
    }
    func applyDrawingParameters(_ drawingTool: DrawingToolModel) {
        bindInputs(drawingTool)
        bindModels(drawingTool)
    }

    func bindUndoModels(_ undoManager: UndoHistoryManager) {
        undoManager.canUndoPublisher
            .assign(to: \.isEnabled, on: undoButton)
            .store(in: &cancellables)

        undoManager.canRedoPublisher
            .assign(to: \.isEnabled, on: redoButton)
            .store(in: &cancellables)
    }

    private func bindInputs(_ drawingTool: DrawingToolModel) {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.tapResetTransformButton?()
        }, for: .touchUpInside)

        saveButton.addAction(.init { [weak self] _ in
            self?.tapSaveButton?()
        }, for: .touchUpInside)

        layerButton.addAction(.init { [weak self] _ in
            self?.tapLayerButton?()
        }, for: .touchUpInside)

        loadButton.addAction(.init { [weak self] _ in
            self?.tapLoadButton?()
        }, for: .touchUpInside)

        exportImageButton.addAction(.init { [weak self] _ in
            self?.tapExportImageButton?()
        }, for: .touchUpInside)

        newButton.addAction(.init { [weak self] _ in
            self?.tapNewButton?()
        }, for: .touchUpInside)

        blackColorButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.brush)
            drawingTool.setBrushColor(UIColor.black.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        redColorButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.brush)
            drawingTool.setBrushColor(UIColor.red.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        eraserButton.addAction(.init { _ in
            drawingTool.setDrawingTool(.eraser)
        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.tapUndoButton?()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.tapRedoButton?()
        }, for: .touchUpInside)

        diameterSlider.addTarget(
            drawingTool,
            action:#selector(drawingTool.handleDiameterSlider),
            for: .valueChanged)
    }

    private func bindModels(_ transforming: TransformingProtocol) {

        transforming.matrixPublisher
            .assign(to: \.matrix, on: canvasView)
            .store(in: &cancellables)
    }

    private func bindModels(_ drawingTool: DrawingToolModel) {

        drawingTool.diameterPublisher
            .assign(to: \.value, on: diameterSlider)
            .store(in: &cancellables)

        drawingTool.backgroundColorPublisher
            .compactMap { $0 }
            .assign(to: \.backgroundColor, on: canvasView)
            .store(in: &cancellables)
    }

}

extension ContentView {

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        canvasView.setNeedsDisplay()
    }

}
