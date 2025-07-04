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

    @IBOutlet private weak var brushDiameterSlider: UISlider!
    @IBOutlet private weak var eraserDiameterSlider: UISlider!

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

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
    }

}

extension CanvasContentView {

    func setup(_ canvasState: CanvasState) {
        addEvents(canvasState)
        bindData(canvasState)
    }

    private func addEvents(_ canvasState: CanvasState) {
        let drawingToolState = canvasState.drawingToolState

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
            drawingToolState.drawingTool = .brush
            drawingToolState.brush.color = UIColor.black.withAlphaComponent(0.75)
        }, for: .touchUpInside)

        redColorButton.addAction(.init { _ in
            drawingToolState.drawingTool = .brush
            drawingToolState.brush.color = UIColor.red.withAlphaComponent(0.75)
        }, for: .touchUpInside)

        eraserButton.addAction(.init { _ in
            drawingToolState.drawingTool = .eraser

        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.tapUndoButton?()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.tapRedoButton?()
        }, for: .touchUpInside)

        brushDiameterSlider.addAction(UIAction { action in
            guard let slider = action.sender as? UISlider else { return }
            drawingToolState.brush.setDiameter(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { action in
            guard let slider = action.sender as? UISlider else { return }
            drawingToolState.eraser.setDiameter(slider.value)
        }, for: .valueChanged)
    }

    private func bindData(_ canvasState: CanvasState) {

        canvasState.drawingToolState.$drawingTool
            .sink { [weak self] type in
                self?.showSlider(type)
            }
            .store(in: &cancellables)

        canvasState.drawingToolState.brush.$diameter
            .map { DrawingBrushToolState.diameterFloatValue($0) }
            .assign(to: \.value, on: brushDiameterSlider)
            .store(in: &cancellables)

        canvasState.drawingToolState.eraser.$diameter
            .map { DrawingEraserToolState.diameterFloatValue($0) }
            .assign(to: \.value, on: eraserDiameterSlider)
            .store(in: &cancellables)

        canvasState.$backgroundColor
            .compactMap { $0 }
            .assign(to: \.backgroundColor, on: canvasView)
            .store(in: &cancellables)
    }

    private func showSlider(_ tool: DrawingToolType) {
        brushDiameterSlider.isHidden = tool != .brush
        eraserDiameterSlider.isHidden = tool != .eraser
    }

}
