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
    var tapDrawingToolButton: (() -> Void)?
    var tapUndoButton: (() -> Void)?
    var tapRedoButton: (() -> Void)?
    var dragBrushSlider: ((Float) -> Void)?
    var dragEraserSlider: ((Float) -> Void)?

    private let throttle = Throttle(delay: 0.2)

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

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
    }

    func initialize() {
        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.canvasView.alpha = 1.0
        }

        backgroundColor = .white
    }

    func undo() {
        canvasView.undo()
    }
    func redo() {
        canvasView.redo()
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        drawingToolButton.setImage(.init(systemName: tool == .brush ? "pencil" : "eraser"), for: .normal)

        brushDiameterSlider.isHidden = tool != .brush
        brushPaletteView.isHidden = tool != .brush

        eraserDiameterSlider.isHidden = tool != .eraser
        eraserPaletteView.isHidden = tool != .eraser

        canvasView.setDrawingTool(tool.rawValue)
    }

    func setBrushDiameterSlider(_ value: Int) {
        brushDiameterSlider.setValue(
            BrushDrawingRenderer.diameterFloatValue(value),
            animated: false
        )
    }
    func setEraserDiameterSlider(_ value: Int) {
        eraserDiameterSlider.setValue(
            EraserDrawingRenderer.diameterFloatValue(value),
            animated: false
        )
    }
    func setBrushDiameterSlider(_ value: Float) {
        brushDiameterSlider.setValue(value, animated: false)
    }
    func setEraserDiameterSlider(_ value: Float) {
        eraserDiameterSlider.setValue(value, animated: false)
    }

    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }

    func enableComponentsInteraction(_ isUserInteractionEnabled: Bool) {
        resetTransformButton.isUserInteractionEnabled = isUserInteractionEnabled
        saveButton.isUserInteractionEnabled = isUserInteractionEnabled
        loadButton.isUserInteractionEnabled = isUserInteractionEnabled
        newButton.isUserInteractionEnabled = isUserInteractionEnabled

        brushDiameterSlider.isUserInteractionEnabled = isUserInteractionEnabled
        eraserDiameterSlider.isUserInteractionEnabled = isUserInteractionEnabled

        exportImageButton.isUserInteractionEnabled = isUserInteractionEnabled
        layerButton.isUserInteractionEnabled = isUserInteractionEnabled

        drawingToolButton.isUserInteractionEnabled = isUserInteractionEnabled

        brushPaletteView.isUserInteractionEnabled = isUserInteractionEnabled
        eraserPaletteView.isUserInteractionEnabled = isUserInteractionEnabled

        undoButton.isUserInteractionEnabled = isUserInteractionEnabled
        redoButton.isUserInteractionEnabled = isUserInteractionEnabled
    }
}

private extension HandDrawingContentView {
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
            self?.tapDrawingToolButton?()
        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            guard let `self` else { return }
            self.throttle.run([self.undoButton, self.redoButton]) {
                self.tapUndoButton?()
            }
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            guard let `self` else { return }
            self.throttle.run([self.undoButton, self.redoButton]) {
                self.tapRedoButton?()
            }
        }, for: .touchUpInside)

        brushDiameterSlider.addAction(UIAction { [weak self] action in
            guard let `self`, let slider = action.sender as? UISlider else { return }
            dragBrushSlider?(slider.value)
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let `self`,  let slider = action.sender as? UISlider else { return }
            dragEraserSlider?(slider.value)
        }, for: .valueChanged)
    }
}
