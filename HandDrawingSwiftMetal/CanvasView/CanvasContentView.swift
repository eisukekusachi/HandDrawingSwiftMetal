//
//  CanvasContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class CanvasContentView: UIView {

    @IBOutlet private(set) weak var canvasView: CanvasView!

    @IBOutlet private weak var resetTransformButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var loadButton: UIButton!
    @IBOutlet private weak var newButton: UIButton!

    @IBOutlet private weak var diameterSlider: UISlider!

    @IBOutlet private weak var blackColorButton: UIButton!
    @IBOutlet private weak var redColorButton: UIButton!
    @IBOutlet private weak var eraserButton: UIButton!
    @IBOutlet private(set) weak var undoButton: UIButton!
    @IBOutlet private(set) weak var redoButton: UIButton!
    @IBOutlet private(set) weak var exportImageButton: UIButton!
    @IBOutlet private(set) weak var layerButton: UIButton!

    var tapResetTransformButton: (() -> Void)?
    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    var tapUndoButton: (() -> Void)?
    var tapRedoButton: (() -> Void)?

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

        undoButton.isHidden = true
        redoButton.isHidden = true
    }

}

extension CanvasContentView {

    func applyDrawingParameters(_ drawingTool: CanvasDrawingToolStatus) {
        bindInputs(drawingTool)
        bindModels(drawingTool)
    }

    private func bindInputs(_ drawingTool: CanvasDrawingToolStatus) {

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

    private func bindModels(_ drawingTool: CanvasDrawingToolStatus) {

        drawingTool.diameterPublisher
            .assign(to: \.value, on: diameterSlider)
            .store(in: &cancellables)

        drawingTool.backgroundColorPublisher
            .compactMap { $0 }
            .assign(to: \.backgroundColor, on: canvasView)
            .store(in: &cancellables)
    }

}
