//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {
    
    private let canvas = Canvas()
    
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var diameterSlider: UISlider! {
        didSet {
            diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        }
    }
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    
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

        canvas.canvasDelegate = self
        canvas.drawingTool = .brush
        canvas.brushColor = UIColor.black.withAlphaComponent(0.75)
        canvas.eraserAlpha = 150

        diameterSlider.value = Brush.diameterFloatValue(canvas.brushDiameter)

        refreshUndoRedoButtons()
    }

    private func refreshUndoRedoButtons() {
        undoButton.isEnabled = canvas.canUndo
        redoButton.isEnabled = canvas.canRedo
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
        
        if let image = canvas.outputImage {
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
    @IBAction func pushUndoButton() {
        canvas.undo()
    }
    @IBAction func pushRedoButton() {
        canvas.redo()
    }
    @IBAction func pushSaveButton() {
        do {
            try saveCanvasData(canvas, zipFileName: canvas.fileNamePath)

        } catch {
            print("Error")
        }
    }
    @IBAction func pushLoadButton() {
        let zipFileList = URL.documents.allFileURLs(suffix: Canvas.zipSuffix).map {
            $0.lastPathComponent
        }
        let fileView = FileView(zipFileList: zipFileList,
                                didTapItem: { fileName in
            print(fileName)
            self.presentedViewController?.dismiss(animated: true)
        })
        let vc = UIHostingController(rootView: fileView)
        self.present(vc, animated: true)
    }
}

extension ViewController: CanvasDelegate {
    func didUndoRedo() {
        refreshUndoRedoButtons()
    }
}
