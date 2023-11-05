//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {
    
    let canvas = Canvas()

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
    
    func refreshUndoRedoButtons() {
        undoButton.isEnabled = canvas.canUndo
        redoButton.isEnabled = canvas.canRedo
    }
    func refreshAllComponents() {
        switch canvas.drawingTool {
        case .brush:
            diameterSlider.value = Brush.diameterFloatValue(canvas.brushDiameter)
        case .eraser:
            diameterSlider.value = Brush.diameterFloatValue(canvas.eraserDiameter)
        }
        refreshUndoRedoButtons()
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
        saveCanvas()
    }
    @IBAction func pushLoadButton() {
        let zipFileList = URL.documents.allFileURLs(suffix: Canvas.zipSuffix).map {
            $0.lastPathComponent
        }
        let fileView = FileView(zipFileList: zipFileList,
                                didTapItem: { [weak self] zipFilePath in

            self?.loadCanvas(zipFilePath: zipFilePath)
            self?.presentedViewController?.dismiss(animated: true)
        })
        let vc = UIHostingController(rootView: fileView)
        self.present(vc, animated: true)
    }
    @IBAction func pushNewButton() {
        showAlert(title: "Alert",
                  message: "Do you want to refresh the canvas?",
                  okHandler: { [weak self] in

            self?.canvas.newCanvas()
        })
    }

    func showAlert(title: String, message: String, okHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let ok = UIAlertAction(title: "OK", style: .default) { _ in
            okHandler()
            self.dismiss(animated: true, completion: nil)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        alert.addAction(cancel)

        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
}

extension ViewController: CanvasDelegate {
    func didUndoRedo() {
        refreshUndoRedoButtons()
    }
}
