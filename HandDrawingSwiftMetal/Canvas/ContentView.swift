//
//  ContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import UIKit

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
