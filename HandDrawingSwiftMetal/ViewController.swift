//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class ViewController: UIViewController {
    
    private let canvas = Canvas()
    
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var diameterSlider: UISlider! {
        didSet {
            diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(canvas)
        view.sendSubviewToBack(canvas)
        
        canvas.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            canvas.leftAnchor.constraint(equalTo: view.leftAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.rightAnchor.constraint(equalTo: view.rightAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        canvas.drawingTool = .brush
        diameterSlider.value = Brush.diameterFloatValue(canvas.brushDiameter)
    }
}

extension ViewController {
    @IBAction func pushResetTransform(_ sender: UIButton) {
        canvas.resetCanvasMatrix()
        canvas.setNeedsDisplay()
    }
    @IBAction func pushBlackColor(_ sender: UIButton) {
        canvas.drawingTool = .brush
        canvas.brushColor = UIColor.black.withAlphaComponent(0.75)

        diameterSlider.value = Brush.diameterFloatValue(canvas.brushDiameter)
    }
    @IBAction func pushRedColor(_ sender: UIButton) {
        canvas.drawingTool = .brush
        canvas.brushColor = UIColor.red.withAlphaComponent(0.75)

        diameterSlider.value = Brush.diameterFloatValue(canvas.brushDiameter)
    }
    
    @IBAction func pushEraserButton(_ sender: UIButton) {
        canvas.drawingTool = .eraser
        canvas.eraserAlpha = 150

        diameterSlider.value = Eraser.diameterFloatValue(canvas.eraserDiameter)
    }
    
    @IBAction func pushExportButton(_ sender: UIButton) {
        // Debounce the button.
        exportButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) { [unowned self] in
            exportButton.isUserInteractionEnabled = true
        }
        
        if let texture = canvas.displayTexture,
           let data = UIImage.makeCFData(texture, flipY: true),
           let image = UIImage.makeImage(cfData: data, width: texture.width, height: texture.height) {
            
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        }
    }
    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            view.addSubview(Toast(text: "Failed"))
        } else {
            view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))
        }
    }
    @IBAction func pushClearButton(_ sender: UIButton) {
        canvas.clearCanvas()
        canvas.setNeedsDisplay()
    }
    @IBAction func dragDiameterSlider(_ sender: UISlider) {
        if canvas.drawingTool == .eraser {
            canvas.eraserDiameter = Int(Eraser.diameterIntValue(sender.value))

        } else {
            canvas.brushDiameter = Int(Brush.diameterIntValue(sender.value))
        }
    }
}
