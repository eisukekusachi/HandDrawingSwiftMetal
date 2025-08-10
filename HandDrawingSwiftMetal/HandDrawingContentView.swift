//
//  HandDrawingContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import CanvasView
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

    @IBOutlet private(set) weak var exportImageButton: UIButton!
    @IBOutlet private(set) weak var layerButton: UIButton!

    @IBOutlet weak var drawingToolButton: UIButton!
    @IBOutlet weak var brushPaletteView: UIStackView!
    @IBOutlet weak var eraserPaletteView: UIStackView!

    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    private let viewModel = HandDrawingContentViewModel()

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
        canvasView.alpha = 0.0

        addEvents()
        addPalettes()

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))

        undoButton.isHidden = true
        redoButton.isHidden = true

        updateDrawingComponents(
            viewModel.drawingTool
        )
    }

    func setup(_ configuration: CanvasConfiguration) {

        brushDiameterSlider.setValue(
            DrawingBrushToolState.diameterFloatValue(configuration.brushDiameter),
            animated: false
        )
        eraserDiameterSlider.setValue(
            DrawingEraserToolState.diameterFloatValue(configuration.eraserDiameter),
            animated: false
        )

        updateDrawingComponents(configuration.drawingTool)

        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.canvasView.alpha = 1.0
        }

        backgroundColor = .white
    }
}

private extension HandDrawingContentView {

    func changeDrawingTool() {
        viewModel.changeDrawingTool()
        updateDrawingComponents(viewModel.drawingTool)
    }

    func addPalettes() {
        let size: CGFloat = 28

        for (index, color) in viewModel.brushColors.enumerated() {
            let colorView = UIButton()
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorView.backgroundColor = color
            colorView.layer.cornerRadius = size * 0.5
            colorView.clipsToBounds = true
            brushPaletteView.addArrangedSubview(colorView)

            colorView.addAction(.init { [weak self] _ in
                guard let `self` else { return }
                self.viewModel.selectedBrushColorIndex = index
                self.canvasView.setBrushColor(self.viewModel.brushColor)
            }, for: .touchUpInside)

            NSLayoutConstraint.activate([
                colorView.widthAnchor.constraint(equalToConstant: size),
                colorView.heightAnchor.constraint(equalToConstant: size)
            ])
        }

        for (index, alpha) in viewModel.eraserAlphas.enumerated() {
            let colorView = UIButton()
            colorView.translatesAutoresizingMaskIntoConstraints = false
            colorView.backgroundColor = .black.withAlphaComponent(CGFloat(alpha) / 255.0)
            colorView.layer.cornerRadius = size * 0.5
            colorView.clipsToBounds = true
            eraserPaletteView.addArrangedSubview(colorView)

            colorView.addAction(.init { [weak self] _ in
                guard let `self` else { return }
                self.viewModel.selectedEraserAlphaIndex = index
                self.canvasView.setEraserAlpha(self.viewModel.eraserAlpha)
            }, for: .touchUpInside)

            NSLayoutConstraint.activate([
                colorView.widthAnchor.constraint(equalToConstant: size),
                colorView.heightAnchor.constraint(equalToConstant: size)
            ])
        }
    }

    func addEvents() {

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

        drawingToolButton.addAction(.init { [weak self] _ in
            self?.changeDrawingTool()
        }, for: .touchUpInside)

/*
        undoButton.addAction(.init { [weak self] _ in
            self?.canvasView.undo()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.canvasView.redo()
        }, for: .touchUpInside)
*/

        brushDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.canvasView.setBrushDiameter(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.canvasView.setEraserDiameter(slider.value)
        }, for: .valueChanged)
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        if tool == .brush {
            drawingToolButton.setImage(.init(systemName: "pencil.line"), for: .normal)

            canvasView.setDrawingTool(.brush)
            canvasView.setBrushColor(viewModel.brushColor)

        } else {
            drawingToolButton.setImage(.init(named: "DrawingEraser"), for: .normal)

            canvasView.setDrawingTool(.eraser)
            canvasView.setEraserAlpha(viewModel.eraserAlpha)
        }

        brushDiameterSlider.isHidden = tool != .brush
        brushPaletteView.isHidden = tool != .brush

        eraserDiameterSlider.isHidden = tool != .eraser
        eraserPaletteView.isHidden = tool != .eraser
    }

    /*
    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }
    */
}
