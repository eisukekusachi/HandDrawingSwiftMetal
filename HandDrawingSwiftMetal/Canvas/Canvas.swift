//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import MetalKit

protocol CanvasDrawingProtocol {
    
    var mtlDevice: MTLDevice { get }
    
    var commandBuffer: MTLCommandBuffer? { get }
    
    var size: CGSize { get }
    var matrix: CGAffineTransform { get }
    var currentLayer: MTLTexture { get }
}
protocol CanvasTextureLayerProtocol {
    
    var mtlDevice: MTLDevice { get }
    var commandBuffer: MTLCommandBuffer? { get }
}
protocol CanvasDelegate: AnyObject {
    
    func completedTextureInitialization(_ canvas: Canvas)
}

class Canvas: MTKView, MTKViewDelegate, CanvasDrawingProtocol, CanvasTextureLayerProtocol {
    
    weak var canvasDelegate: CanvasDelegate?
    
    var mtlDevice: MTLDevice {
        return self.device!
    }
    var size: CGSize {
        return frame.size
    }
    var commandBuffer: MTLCommandBuffer? {
        return commandQueue.getBuffer()
    }
    var currentLayer: MTLTexture {
        return layers.currentLayer
    }
    
    var commandQueue: CommandQueue!
    
    lazy var drawingLayer: CanvasDrawingLayer = BrushDrawingLayer(canvas: self)
    var transforming: Transforming = TransformingImpl()
    
    var matrix: CGAffineTransform = CGAffineTransform.identity
    
    var textureSize: CGSize!
    var displayTexture: MTLTexture!
    
    private lazy var layers: CanvasLayers = DefaultLayers(canvas: self)
    
    private lazy var defaultFingerInput: FingerGestureRecognizer = FingerGestureRecognizer(output: self)
    private lazy var defaultFingerPoints: SmoothPointStorage? = SmoothPointStorage()
    
    private var displayLink: CADisplayLink?
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        self.device = MTLCreateSystemDefaultDevice()
        let myCommandQueue = self.device!.makeCommandQueue()
        assert(self.device != nil, "device is nil.")
        assert(myCommandQueue != nil, "commandQueue is nil.")
        
        Pipeline.initalization(mtlDevice)
        
        commandQueue = CommandQueueImpl(queue: myCommandQueue!)
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
        
        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
        
        self.addGestureRecognizer(defaultFingerInput)
    }
    func disableDefaultDrawing() {
        defaultFingerInput.isEnabled = false
        defaultFingerPoints = nil
    }
    
    override func layoutSubviews() {
        if  let drawableSize = currentDrawable?.texture.size,
                displayTexture == nil {
            
            initalizeTextures(textureSize: drawableSize)
        }
        
        if  drawingLayer.textureSize == .zero && self.textureSize != .zero {
            drawingLayer.initalizeTextures(textureSize: self.textureSize)
        }
        
        refreshDisplayTexture()
        setNeedsDisplay()
    }
    
    func initalizeTextures(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(Command.threadgroupSize)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")
        
        self.textureSize = textureSize
        
        displayTexture = mtlDevice.makeTexture(textureSize)
        layers.initalizeLayers(layerSize: textureSize)
        
        canvasDelegate?.completedTextureInitialization(self)
    }
    
    func inject(drawingLayer: CanvasDrawingLayer) {
        self.drawingLayer = drawingLayer
    }
    func inject(layers: CanvasLayers) {
        self.layers = layers
    }
    
    
    // MARK: Drawing
    func prepareForNewDrawing() {
        defaultFingerPoints?.reset()
        
        drawingLayer.clear()
        displayLink?.isPaused = true
    }
    func setNeedsDisplayByRunningDisplayLink(pauseDisplayLink: Bool) {
        
        if !pauseDisplayLink {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
            
        } else {
            displayLink?.isPaused = true
            setNeedsDisplay()
        }
    }
    func refreshDisplayTexture() {
        
        layers.flatAllLayers(currentLayer: drawingLayer.currentLayer,
                             backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                             toDisplayTexture: displayTexture)
    }
    func clear() {
        layers.clear()
        refreshDisplayTexture()
    }
    
    
    // MARK: MTKViewDelegate
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        var canvasMatrix = matrix
        canvasMatrix.tx *= (CGFloat(drawable.texture.width) / frame.size.width)
        canvasMatrix.ty *= (CGFloat(drawable.texture.height) / frame.size.height)
        
        let textureBuffers = Buffers.makeTextureBuffers(device: mtlDevice,
                                                        textureSize: displayTexture.size,
                                                        drawableSize: drawable.texture.size,
                                                        matrix: canvasMatrix,
                                                        nodes: textureNodes)
        
        let commandBuffer = commandQueue.getBuffer()
        
        Command.draw(texture: displayTexture,
                     buffers: textureBuffers,
                     on: drawable.texture,
                     clearColor: (230, 230, 230),
                     to: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        commandQueue.reset()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    
    // MARK: Events
    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        setNeedsDisplay()
    }
}

// MARK: Drawing a line on the canvas.
extension Canvas: FingerGestureRecognizerSender {
    func sendLocations(_ gesture: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState) {
        
        guard let defaultFingerPoints = defaultFingerPoints else { return }
        
        defaultFingerPoints.appendPoints(touchLocations)
        
        let iterator = defaultFingerPoints.getIterator(endProcessing: touchState == .ended)
        drawingLayer.drawOnCellTexture(iterator, touchState: touchState)
        
        if touchState == .ended {
            drawingLayer.mergeCellTextureIntoCurrentLayer()
            prepareForNewDrawing()
        }
        
        refreshDisplayTexture()
        setNeedsDisplayByRunningDisplayLink(pauseDisplayLink: touchState == .ended)
    }
    func cancel(_ gesture: FingerGestureRecognizer?) {
        prepareForNewDrawing()
    }
}

private extension MTLTexture {
    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
}
