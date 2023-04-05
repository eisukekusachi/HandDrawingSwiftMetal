//
//  Canvas.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import MetalKit

protocol CanvasDrawingProtocol {
    
    var mtlDevice: MTLDevice? { get }
    
    var commandBuffer: MTLCommandBuffer? { get }
    
    var size: CGSize { get }
    var drawingMatrix: CGAffineTransform? { get }
    var currentTexture: MTLTexture? { get }
    
    func refreshDisplayTexture(using textures: [MTLTexture?])
}

protocol CanvasDelegate: AnyObject {
    
    func completeTextureSizeDetermination(_ canvas: Canvas)
}

class Canvas: MTKView, MTKViewDelegate, CanvasDrawingProtocol {
    
    weak var canvasDelegate: CanvasDelegate?
    
    var mtlDevice: MTLDevice? {
        return self.device
    }
    var size: CGSize {
        return frame.size
    }
    var commandBuffer: MTLCommandBuffer? {
        return commandQueue.getBuffer()
    }
    
    var commandQueue: CommandQueue!
    
    var drawing: Drawing = BrushDrawing()
    var transforming: Transforming = TransformingImpl()
    
    var matrix: CGAffineTransform = CGAffineTransform.identity
    var drawingMatrix: CGAffineTransform? {
        return matrix.getInvertedValue(scale: Aspect.getScaleToFit(frame.size, to: textureSize))
    }
    
    var textureSize: CGSize!
    var displayTexture: MTLTexture?
    var currentTexture: MTLTexture?
    
    private var defaultFingerInput: FingerGestureRecognizer!
    private var defaultFingerPoints: SmoothPointStorage?
    
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
        
        Pipeline.initalization(self.device!)
        
        commandQueue = CommandQueueImpl(queue: myCommandQueue!)
        
        defaultFingerPoints = SmoothPointStorage()
        defaultFingerInput = FingerGestureRecognizer(output: self)
        addGestureRecognizer(defaultFingerInput)
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true
        
        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
    }
    override func layoutSubviews() {
        if  let drawableSize = currentDrawable?.texture.size,
                displayTexture == nil {
            
            initalizeTextures(textureSize: drawableSize)
            refreshDisplayTexture()
            setNeedsDisplay()
        }
        
        if  drawing.textureSize == .zero && self.textureSize != .zero {
            drawing.initalizeTexturesForDrawing(self, textureSize: self.textureSize)
            setNeedsDisplay()
        }
    }
    
    func initalizeTextures(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(Command.threadgroupSize)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")
        
        self.textureSize = textureSize
        
        displayTexture = Texture.makeTexture(device, textureSize)
        currentTexture = Texture.makeTexture(device, textureSize)
        
        let commandBuffer = commandQueue.getBuffer()
        
        Command.clear(textures: [displayTexture,
                                 currentTexture],
                      to: commandBuffer)
        
        canvasDelegate?.completeTextureSizeDetermination(self)
    }
    
    func inject(drawing: Drawing) {
        self.drawing = drawing
    }
    
    func prepareForNewDrawing() {
        defaultFingerPoints?.reset()
        
        drawing.reset(self)
        displayLink?.isPaused = true
    }
    func refreshDisplayTexture(using textures: [MTLTexture?] = []) {
        let commandBuffer = commandQueue.getBuffer()
        
        Command.draw(onDisplayTexture: displayTexture,
                     backgroundColor: backgroundColor?.rgb ?? (255, 255, 255),
                     textures: textures,
                     to: commandBuffer)
    }
    func draw(displayTexture: MTLTexture?,
              onDrawable drawable: CAMetalDrawable,
              to commandBuffer: MTLCommandBuffer?) {
        
        guard let displayTexture = displayTexture else { return }
        
        var canvasMatrix = matrix
        canvasMatrix.tx *= (CGFloat(drawable.texture.width) / frame.size.width)
        canvasMatrix.ty *= (CGFloat(drawable.texture.height) / frame.size.height)
        
        let textureBuffers = Buffers.makeTextureBuffers(device: device,
                                                        textureSize: displayTexture.size,
                                                        drawableSize: drawable.texture.size,
                                                        matrix: canvasMatrix,
                                                        nodes: textureNodes)
        
        Command.draw(texture: displayTexture,
                     buffers: textureBuffers,
                     on: drawable.texture,
                     clearColor: (230, 230, 230),
                     to: commandBuffer)
    }
    
    func clear() {
        let commandBuffer = commandQueue.getBuffer()
        
        Command.clear(textures: [displayTexture,
                                 currentTexture],
                      to: commandBuffer)
        
        refreshDisplayTexture()
    }
    
    func disableDefaultDrawing() {
        defaultFingerInput.isEnabled = false
        defaultFingerPoints = nil
    }
    
    
    // MARK: Displaylink
    func setNeedsDisplayForDrawing(_ touchState: TouchState) {
        
        if touchState == .ended {
            displayLink?.isPaused = true
            setNeedsDisplay()
            
        } else {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
        }
    }
    @objc private func displayLinkUpdate(_ displayLink: CADisplayLink) {
        setNeedsDisplay()
    }
    
    // MARK: MTKViewDelegate
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        let commandBuffer = commandQueue.getBuffer()
        
        draw(displayTexture: displayTexture,
             onDrawable: drawable,
             to: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        commandQueue.reset()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

// MARK: Drawing a line on the canvas.
extension Canvas: FingerGestureRecognizerSender {
    func sendLocations(_ gesture: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState) {
        
        defaultFingerPoints?.appendPoints(touchLocations)
        
        let iterator = defaultFingerPoints?.getIterator(endProcessing: touchState == .ended)
        drawing.execute(iterator, endProcessing: touchState == .ended, toward: self)
        
        if touchState == .ended {
            drawing.finishExecuting(self)
            prepareForNewDrawing()
        }
        
        drawing.refresh(self)
        setNeedsDisplayForDrawing(touchState)
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
