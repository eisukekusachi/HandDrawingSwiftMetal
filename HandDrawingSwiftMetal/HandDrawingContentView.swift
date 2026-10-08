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

    @IBOutlet private(set) weak var baseView: UIView!

    @IBOutlet private weak var resetTransformButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var loadButton: UIButton!

    @IBOutlet private(set) weak var brushDiameterView: UIView!
    @IBOutlet private(set) weak var eraserDiameterView: UIView!

    @IBOutlet private(set) weak var exportImageButton: UIButton!
    @IBOutlet private(set) weak var layerButton: UIButton!

    @IBOutlet weak var drawingToolButton: UIButton!

    @IBOutlet weak var brushPaletteView: UIView!
    @IBOutlet weak var eraserPaletteView: UIView!
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapResetTransforming: (() -> Void)?
    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?
    var tapDrawingToolButton: (() -> Void)?
    var tapUndoButton: (() -> Void)?
    var tapRedoButton: (() -> Void)?

    private let throttle = Throttle(delay: 0.05)

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

        baseView.alpha = 0.0

        addEvents()
    }

    func showCanvasAfterCompletion() {
        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.baseView.alpha = 1.0
        }
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        drawingToolButton.setImage(.init(systemName: tool == .brush ? "pencil" : "eraser"), for: .normal)

        brushDiameterView.isHidden = tool != .brush
        brushPaletteView.isHidden = tool != .brush

        eraserDiameterView.isHidden = tool != .eraser
        eraserPaletteView.isHidden = tool != .eraser
    }

    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }

    func enableComponentsInteraction(_ isUserInteractionEnabled: Bool) {
        resetTransformButton.isUserInteractionEnabled = isUserInteractionEnabled
        saveButton.isUserInteractionEnabled = isUserInteractionEnabled
        loadButton.isUserInteractionEnabled = isUserInteractionEnabled

        brushDiameterView.isUserInteractionEnabled = isUserInteractionEnabled
        eraserDiameterView.isUserInteractionEnabled = isUserInteractionEnabled

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
            self?.tapResetTransforming?()
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
    }
}
