//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import SwiftUI
import Combine

class ViewController: UIViewController {
    let canvasViewModel = CanvasViewModel()
    let canvasView = CanvasView()

    lazy var layerViewController = UIHostingController<LayerView>(rootView: LayerView(layerManager: canvasViewModel.layerManager))

    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var diameterSlider: UISlider! {
        didSet {
            diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        }
    }
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    @IBOutlet weak var layerButton: UIButton!

    @IBOutlet weak var topStackView: UIStackView!

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(canvasView)
        view.sendSubviewToBack(canvasView)

        canvasView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            canvasView.leftAnchor.constraint(equalTo: view.leftAnchor),
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.rightAnchor.constraint(equalTo: view.rightAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        canvasView.setViewModel(canvasViewModel)
        canvasView.drawingTool = .brush
        canvasView.brushColor = UIColor.black.withAlphaComponent(0.75)
        canvasView.brushDiameter = 8
        canvasView.eraserAlpha = 150
        canvasView.eraserDiameter = 44

        canvasView.$undoCount
            .sink { [weak self] _ in
                self?.refreshUndoRedoButtons()
            }
            .store(in: &cancellables)

        diameterSlider.value = DrawingToolBrush.diameterFloatValue(canvasView.brushDiameter)
    }
    func initAllComponents() {
        switch canvasView.drawingTool {
        case .brush:
            diameterSlider.value = DrawingToolBrush.diameterFloatValue(canvasView.brushDiameter)
        case .eraser:
            diameterSlider.value = DrawingToolBrush.diameterFloatValue(canvasView.eraserDiameter)
        }
        canvasView.clearUndo()
        refreshUndoRedoButtons()
    }
    func refreshUndoRedoButtons() {
        undoButton.isEnabled = canvasView.canUndo
        redoButton.isEnabled = canvasView.canRedo
    }
}

extension ViewController {
    @IBAction func pushResetTransform(_ sender: UIButton) {
        canvasView.resetMatrix()
        canvasView.setNeedsDisplay()
    }
    @IBAction func pushBlackColor(_ sender: UIButton) {
        canvasView.drawingTool = .brush
        canvasView.brushColor = UIColor.black.withAlphaComponent(0.75)

        diameterSlider.value = DrawingToolBrush.diameterFloatValue(canvasView.brushDiameter)
    }
    @IBAction func pushRedColor(_ sender: UIButton) {
        canvasView.drawingTool = .brush
        canvasView.brushColor = UIColor.red.withAlphaComponent(0.75)

        diameterSlider.value = DrawingToolBrush.diameterFloatValue(canvasView.brushDiameter)
    }
    
    @IBAction func pushEraserButton(_ sender: UIButton) {
        canvasView.drawingTool = .eraser
        canvasView.eraserAlpha = 150

        diameterSlider.value = DrawingToolEraser.diameterFloatValue(canvasView.eraserDiameter)
    }
    
    @IBAction func pushExportButton(_ sender: UIButton) {
        // Debounce the button.
        exportButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) { [unowned self] in
            exportButton.isUserInteractionEnabled = true
        }
        
        if let image = canvasView.rootTexture?.uiImage {
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
    @IBAction func dragDiameterSlider(_ sender: UISlider) {
        if canvasView.drawingTool == .eraser {
            canvasView.eraserDiameter = Int(DrawingToolEraser.diameterIntValue(sender.value))

        } else {
            canvasView.brushDiameter = Int(DrawingToolBrush.diameterIntValue(sender.value))
        }
    }
    @IBAction func pushUndoButton() {
        canvasView.undo()
    }
    @IBAction func pushRedoButton() {
        canvasView.redo()
    }
    @IBAction func pushLayerButton() {
        toggleLayerVisibility()
    }
    @IBAction func pushSaveButton() {
        saveCanvas(into: URL.tmpFolderURL,
                   with: canvasViewModel.zipFileNameName)
    }
    @IBAction func pushLoadButton() {
        let zipFileList = URL.documents.allFileURLs(suffix: CanvasViewModel.zipSuffix).map {
            $0.lastPathComponent
        }
        let fileView = FileView(zipFileList: zipFileList,
                                didTapItem: { [weak self] zipFilePath in

            self?.loadCanvas(from: zipFilePath,
                             into: URL.tmpFolderURL)
            self?.presentedViewController?.dismiss(animated: true)
        })
        let vc = UIHostingController(rootView: fileView)
        self.present(vc, animated: true)
    }
    @IBAction func pushNewButton() {
        showAlert(title: "Alert",
                  message: "Do you want to refresh the canvas?",
                  okHandler: { [weak self] in

            self?.canvasView.newCanvas()
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
