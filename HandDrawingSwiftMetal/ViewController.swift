//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var diameterSlider: UISlider! {
        didSet {
            diameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        }
    }
    
    private let canvas = Canvas()
    
    private let inputManager = InputManager()
    private let actionStateManager = ActionStateManager()
    
    private var pencilPoints = DefaultPointStorage()
    private var fingerPoints = SmoothPointStorage()
    
    private lazy var brushDrawing = BrushDrawingLayer(canvas: canvas)
    private lazy var eraserDrawing = EraserDrawingLayer(canvas: canvas)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(canvas)
        
        canvas.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            canvas.leftAnchor.constraint(equalTo: view.leftAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.rightAnchor.constraint(equalTo: view.rightAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        canvas.canvasDelegate = self
        
        canvas.inject(drawingLayer: brushDrawing)
        let pencilInput = PencilGestureRecognizer(output: self)
        let fingerInput = FingerGestureRecognizer(output: self,
                                                  is3DTouchAvailable: traitCollection.forceTouchCapability == .available)
        canvas.disableDefaultDrawing()
        canvas.addGestureRecognizer(pencilInput)
        canvas.addGestureRecognizer(fingerInput)
        
        
        /*
        canvas.initalizeTextures(textureSize: CGSize(width: 1000, height: 1000))
        canvas.refreshDisplayTexture()
        canvas.setNeedsDisplay()
        */
        
        
        view.sendSubviewToBack(canvas)
        view.backgroundColor = .white
        overrideUserInterfaceStyle = .light
        
        diameterSlider.value = Float(brushDrawing.brush.diameter) / Float(Brush.maxDiameter)
    }
    private func cancelOperation() {
        inputManager.reset()
        actionStateManager.reset()
        
        pencilPoints.reset()
        fingerPoints.reset()
        
        canvas.prepareForNewDrawing()
        
        canvas.matrix = canvas.transforming.storedMatrix
        canvas.setNeedsDisplay()
    }
}

extension ViewController: PencilGestureRecognizerSender {
    func sendLocations(_ gesture: PencilGestureRecognizer?, touchLocations: [Point], touchState: TouchState) {
        
        if inputManager.currentInput is FingerGestureRecognizer {
            
            fingerPoints.reset()
            canvas.matrix = canvas.transforming.storedMatrix
            canvas.prepareForNewDrawing()
        }
        if touchState == .began {
            inputManager.update(gesture)
        }
        
        
        pencilPoints.appendPoints(touchLocations)
        
        let iterator = pencilPoints.getIterator(endProcessing: touchState == .ended)
        canvas.drawingLayer.drawOnCellTexture(iterator, touchState: touchState)
        
        if touchState == .ended {
            canvas.drawingLayer.mergeCellTextureIntoCurrentLayer()
            canvas.prepareForNewDrawing()
        }
        
        canvas.refreshDisplayTexture()
        canvas.setNeedsDisplayByRunningDisplayLink(pauseDisplayLink: touchState == .ended)
        
        if touchState == .ended {
            inputManager.reset()
            actionStateManager.reset()
            
            pencilPoints.reset()
        }
    }
    func cancel(_ gesture: PencilGestureRecognizer?) {
        
        cancelOperation()
    }
}

extension ViewController: FingerGestureRecognizerSender {
    func sendLocations(_ gesture: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState) {
        if touchState == .began {
            inputManager.update(gesture)
        }
        guard inputManager.currentInput is FingerGestureRecognizer else { return }
        
        
        fingerPoints.appendPoints(touchLocations)
        
        actionStateManager.update(ActionState.getCurrentState(viewTouches: fingerPoints.storedPoints))
        
        if actionStateManager.currentState == .drawingOnCanvas {
            
            let iterator = fingerPoints.getIterator(endProcessing: touchState == .ended)
            canvas.drawingLayer.drawOnCellTexture(iterator, touchState: touchState)
            
            if touchState == .ended {
                canvas.drawingLayer.mergeCellTextureIntoCurrentLayer()
                canvas.prepareForNewDrawing()
            }
            
            canvas.refreshDisplayTexture()
            canvas.setNeedsDisplayByRunningDisplayLink(pauseDisplayLink: touchState == .ended)
        }
        
        if actionStateManager.currentState == .transformingCanvas {
            if let matrix = canvas.transforming.update(viewTouches: fingerPoints.storedPoints,
                                                       viewSize: canvas.frame.size) {
                canvas.matrix = matrix
            }
            
            if touchState == .ended {
                canvas.transforming.endTransforming(canvas.matrix)
            }
            
            canvas.setNeedsDisplay()
        }
        
        if touchState == .ended {
            inputManager.reset()
            actionStateManager.reset()
            
            fingerPoints.reset()
        }
    }
    func cancel(_ gesture: FingerGestureRecognizer?) {
        guard inputManager.currentInput is FingerGestureRecognizer else { return }
        
        cancelOperation()
    }
}
extension ViewController: CanvasDelegate {
    func completedTextureInitialization(_ canvas: Canvas) {
        
        brushDrawing.initalizeTextures(textureSize: canvas.textureSize)
        eraserDrawing.initalizeTextures(textureSize: canvas.textureSize)
    }
}

extension ViewController {
    @IBAction func pushResetTransform(_ sender: UIButton) {
        canvas.transforming.reset()
        canvas.matrix = canvas.transforming.storedMatrix
        
        canvas.setNeedsDisplay()
    }
    @IBAction func pushBlackColor(_ sender: UIButton) {
        brushDrawing.brush.setValue(rgb: (0, 0, 0))
        canvas.inject(drawingLayer: brushDrawing)
        
        diameterSlider.value = Float(brushDrawing.brush.diameter) / Float(Brush.maxDiameter)
    }
    @IBAction func pushRedColor(_ sender: UIButton) {
        brushDrawing.brush.setValue(rgb: (255, 0, 0))
        canvas.inject(drawingLayer: brushDrawing)
        
        diameterSlider.value = Float(brushDrawing.brush.diameter) / Float(Brush.maxDiameter)
    }
    
    @IBAction func pushEraserButton(_ sender: UIButton) {
        eraserDrawing.eraser.setValue(alpha: 200)
        canvas.inject(drawingLayer: eraserDrawing)
        
        diameterSlider.value = Float(eraserDrawing.eraser.diameter) / Float(Eraser.maxDiameter)
    }
    
    @IBAction func pushExportButton(_ sender: UIButton) {
        // Debounce the button.
        exportButton.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) { [unowned self] in
            exportButton.isUserInteractionEnabled = true
        }
        
        if let texture = canvas.displayTexture,
           let data = Image.makeCFData(texture, flipY: true),
           let image = Image.makeImage(cfData: data, width: texture.width, height: texture.height) {
            
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
        canvas.clear()
        canvas.setNeedsDisplay()
    }
    @IBAction func dragDiameterSlider(_ sender: UISlider) {
        if canvas.drawingLayer is BrushDrawingLayer {
            let difference: Float = Float(Brush.maxDiameter - Brush.minDiameter)
            let value: Int = Int(difference * sender.value) + Brush.minDiameter
            
            brushDrawing.brush.diameter = value
        }
        
        if canvas.drawingLayer is EraserDrawingLayer {
            let difference: Float = Float(Eraser.maxDiameter - Eraser.minDiameter)
            let value: Int = Int(difference * sender.value) + Eraser.minDiameter
            
            eraserDrawing.eraser.diameter = value
        }
    }
}
