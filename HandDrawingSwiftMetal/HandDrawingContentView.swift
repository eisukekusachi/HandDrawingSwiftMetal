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

    @IBOutlet weak var brushPaletteView: UIView!
    @IBOutlet weak var eraserPaletteView: UIView!
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    let brush = DrawingBrushTextureSet()
    let eraser = DrawingEraserTextureSet()

    let viewModel = HandDrawingContentViewModel()

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

        subscribe()
        addEvents()

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))

        undoButton.isHidden = true
        redoButton.isHidden = true

        updateDrawingComponents(
            viewModel.drawingTool
        )
    }

    func setup(_ configuration: CanvasResolvedConfiguration) {
        let brushDiameter = DrawingBrushTextureSet.diameterFloatValue(brush.getDiameter())
        let eraserDiameter = DrawingEraserTextureSet.diameterFloatValue(eraser.getDiameter())

        brush.setDiameter(brushDiameter)
        brushDiameterSlider.setValue(brushDiameter, animated: false)

        eraser.setDiameter(eraserDiameter)
        eraserDiameterSlider.setValue(eraserDiameter, animated: false)

        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.canvasView.alpha = 1.0
        }

        backgroundColor = .white
    }
}

private extension HandDrawingContentView {

    func subscribe() {
        viewModel.brushPalette.$currentIndex
            .sink { [weak self] index in
                guard let `self`, index < viewModel.brushPalette.colors.count else { return }
                let newColor = viewModel.brushPalette.colors[index]
                self.brush.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPalette.$currentIndex
            .sink { [weak self] index in
                guard let `self`, index < viewModel.eraserPalette.alphas.count else { return }
                let newAlpha = viewModel.eraserPalette.alphas[index]
                self.eraser.setAlpha(newAlpha)
            }
            .store(in: &cancellables)
    }

    func changeDrawingTool() {
        viewModel.changeDrawingTool()
        updateDrawingComponents(viewModel.drawingTool)
    }

    func addEvents() {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.canvasView.resetTransforming()
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
            self?.brush.setDiameter(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.eraser.setDiameter(slider.value)
        }, for: .valueChanged)
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        if tool == .brush {
            drawingToolButton.setImage(.init(systemName: "pencil.line"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.brush.rawValue)

        } else {
            drawingToolButton.setImage(.init(named: "DrawingEraser"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.eraser.rawValue)
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
