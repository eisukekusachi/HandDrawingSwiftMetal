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
    }

}
