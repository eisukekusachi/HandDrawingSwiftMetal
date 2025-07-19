//
//  HandDrawingContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit
import Combine

final class HandDrawingContentView: UIView {

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

    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

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
        addEvents()

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
    }
}

extension HandDrawingContentView {

    private func addEvents() {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.canvasView.resetTransforming()
        }, for: .touchUpInside)

        saveButton.addAction(.init { [weak self] _ in
            self?.canvasView.saveFile()
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

        blackColorButton.addAction(.init { [weak self] _ in
            self?.setBlackBrushColor()
        }, for: .touchUpInside)

        redColorButton.addAction(.init { [weak self] _ in
            self?.setRedBrushColor()
        }, for: .touchUpInside)

        eraserButton.addAction(.init { [weak self] _ in
            self?.setEraser()

        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.canvasView.undo()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.canvasView.redo()
        }, for: .touchUpInside)

        brushDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.canvasView.setBrushDiameter(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.canvasView.setEraserDiameter(slider.value)
        }, for: .valueChanged)
    }

    private func showSlider(_ tool: DrawingToolType) {
        brushDiameterSlider.isHidden = tool != .brush
        eraserDiameterSlider.isHidden = tool != .eraser
    }
}

extension HandDrawingContentView {

    func setup(_ configuration: CanvasConfiguration) {

        brushDiameterSlider.setValue(
            DrawingBrushToolState.diameterFloatValue(configuration.brushDiameter),
            animated: false
        )
        eraserDiameterSlider.setValue(
            DrawingEraserToolState.diameterFloatValue(configuration.eraserDiameter),
            animated: false
        )

        canvasView.setBrushColor(configuration.brushColor)
        canvasView.setDrawingTool(configuration.drawingTool)

        showSlider(configuration.drawingTool)

        backgroundColor = .white
    }

    func setBlackBrushColor() {
        showSlider(.brush)
        canvasView.setDrawingTool(.brush)
        canvasView.setBrushColor(UIColor.black.withAlphaComponent(0.75))
    }
    func setRedBrushColor() {
        showSlider(.brush)
        canvasView.setDrawingTool(.brush)
        canvasView.setBrushColor(UIColor.red.withAlphaComponent(0.75))
    }
    func setEraser() {
        showSlider(.eraser)
        canvasView.setDrawingTool(.eraser)
    }

    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }
}
