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
    }

}

extension ContentView {

    func applyDrawingParameters(_ parameters: DrawingParameters) {
        bindInputs(parameters)
        bindModels(parameters)
    }

    private func bindInputs(_ parameters: DrawingParameters) {

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
            parameters.setDrawingTool(.brush)
            parameters.setBrushColor(UIColor.black.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        redColorButton.addAction(.init { _ in
            parameters.setDrawingTool(.brush)
            parameters.setBrushColor(UIColor.red.withAlphaComponent(0.75))
        }, for: .touchUpInside)

        eraserButton.addAction(.init { _ in
            parameters.setDrawingTool(.eraser)
        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.tapUndoButton?()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.tapRedoButton?()
        }, for: .touchUpInside)

        diameterSlider.addTarget(
            parameters,
            action:#selector(parameters.handleDiameterSlider), for: .valueChanged)
    }
    
    private func bindModels(_ parameters: DrawingParameters) {

        parameters.diameterSubject
            .sink { [weak self] diameter in
                self?.diameterSlider.value = diameter
            }
            .store(in: &cancellables)

        parameters.backgroundColorSubject
            .sink { [weak self] color in
                self?.canvasView.backgroundColor = color
            }
            .store(in: &cancellables)
    }

}
