//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var canvas = Canvas(delegate: self)
    
    private let inputManager = InputManager() /// A manager of finger input and pen input.
    private let actionStateManager = ActionStateManager() /// A manager of one finger drag or two fingers pinch.
    
    private var pencilPoints = DefaultPointStorage()
    private var fingerPoints = SmoothPointStorage()
    
    /// Draw a line on the drawingLayer and merge the drawingLayer to the currentLayer of the canvas at the touchEnded
    /// in order to be able to cancel drawing in the middle of drawing a line.
    private lazy var brushDrawingLayer = BrushDrawingLayer(canvas: canvas,
                                                           drawingtoolDiameter: 8,
                                                           brushColor: colorData.brushColorArray[0])
    private lazy var eraserDrawingLayer = EraserDrawingLayer(canvas: canvas,
                                                             drawingtoolDiameter: 32,
                                                             eraserAlpha: colorData.eraserAlpha)
    
    private let colorData = ColorData()
    
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
        
        canvas.inject(drawingLayer: brushDrawingLayer)
        
        canvas.disableDefaultGestureRecognizer()
        canvas.addGestureRecognizer(PencilGestureRecognizer(output: self))
        canvas.addGestureRecognizer(FingerGestureRecognizer(output: self,
                                                            is3DTouchAvailable: traitCollection.forceTouchCapability == .available))
        
        /*
        canvas.initalizeTextures(textureSize: CGSize(width: 1000, height: 1000))
        canvas.refreshDisplayTexture()
        canvas.setNeedsDisplay()
        */
        
        diameterSlider.value = Float(canvas.drawingLayer.drawingtoolDiameter) / Float(Brush.maxDiameter)
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
extension ViewController: CanvasDelegate {
    func didCompletTextureInitialization(_ canvas: Canvas) {
        
        brushDrawingLayer.initalizeTextures(textureSize: canvas.textureSize)
        eraserDrawingLayer.initalizeTextures(textureSize: canvas.textureSize)
    }
}

extension ViewController: PencilGestureRecognizerSender {
    func sendLocations(_ input: PencilGestureRecognizer?, touchLocations: [Point], touchState: TouchState) {
        
        // Cancel drawing a line when the currentInput is the finger input.
        if inputManager.currentInput is FingerGestureRecognizer {
            
            fingerPoints.reset()
            canvas.matrix = canvas.transforming.storedMatrix
            canvas.prepareForNewDrawing()
        }
        
        
        if touchState == .began {
            inputManager.update(input)
        }
        
        pencilPoints.appendPoints(touchLocations)
        
        let iterator = pencilPoints.getIterator(endProcessing: touchState == .ended)
        canvas.drawingLayer.drawOnDrawingLayer(with: iterator, touchState: touchState)
        
        if touchState == .ended {
            canvas.drawingLayer.mergeDrawingLayerIntoCurrentLayer()
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
    func sendLocations(_ input: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState) {
        
        if touchState == .began {
            inputManager.update(input)
        }
        guard inputManager.currentInput is FingerGestureRecognizer else { return }
        
        
        fingerPoints.appendPoints(touchLocations)
        
        let currentActionState = ActionState.getCurrentState(viewTouches: fingerPoints.storedPoints)
        actionStateManager.update(currentActionState)
        
        if actionStateManager.currentState == .drawingOnCanvas {
            
            let iterator = fingerPoints.getIterator(endProcessing: touchState == .ended)
            canvas.drawingLayer.drawOnDrawingLayer(with: iterator, touchState: touchState)
            
            if touchState == .ended {
                canvas.drawingLayer.mergeDrawingLayerIntoCurrentLayer()
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
    func cancel(_ input: FingerGestureRecognizer?) {
        guard inputManager.currentInput is FingerGestureRecognizer else { return }
        
        cancelOperation()
    }
}

extension ViewController {
    @IBAction func pushResetTransform(_ sender: UIButton) {
        canvas.transforming.reset()
        canvas.matrix = canvas.transforming.storedMatrix
        
        canvas.setNeedsDisplay()
    }
    @IBAction func pushBlackColor(_ sender: UIButton) {
        brushDrawingLayer.brush.setValue(color: colorData.brushColorArray[0])
        canvas.inject(drawingLayer: brushDrawingLayer)
        
        diameterSlider.value = Float(brushDrawingLayer.brush.diameter) / Float(Brush.maxDiameter)
    }
    @IBAction func pushRedColor(_ sender: UIButton) {
        brushDrawingLayer.brush.setValue(color: colorData.brushColorArray[1])
        canvas.inject(drawingLayer: brushDrawingLayer)
        
        diameterSlider.value = Float(brushDrawingLayer.brush.diameter) / Float(Brush.maxDiameter)
    }
    
    @IBAction func pushEraserButton(_ sender: UIButton) {
        eraserDrawingLayer.eraser.setValue(alpha: colorData.eraserAlpha)
        canvas.inject(drawingLayer: eraserDrawingLayer)
        
        diameterSlider.value = Float(eraserDrawingLayer.eraser.diameter) / Float(Eraser.maxDiameter)
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
        canvas.clear()
        canvas.setNeedsDisplay()
    }
    @IBAction func dragDiameterSlider(_ sender: UISlider) {
        
        var value: Int?
        
        if canvas.drawingLayer is BrushDrawingLayer {
            value = Int(sender.value * Float(Brush.maxDiameter - Brush.minDiameter)) + Brush.minDiameter
        }
        if canvas.drawingLayer is EraserDrawingLayer {
            value = Int(sender.value * Float(Eraser.maxDiameter - Eraser.minDiameter)) + Eraser.minDiameter
        }
        
        if let value = value {
            canvas.drawingLayer.drawingtoolDiameter = value
        }
    }
}
