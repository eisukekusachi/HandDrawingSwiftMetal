//
//  EraserDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

class EraserDrawingLayer: CanvasDrawingLayer {
    
    var eraser = Eraser()
    
    var textureSize: CGSize = .zero
    
    var canvas: CanvasDrawingProtocol
    var currentLayer: [MTLTexture?] {
        return isDrawing ? [eraserTexture] : [canvas.currentLayer]
    }
    
    var drawingtoolDiameter: Int {
        get {
            return eraser.diameter
        }
        set {
            eraser.diameter = newValue
        }
    }
    
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!
    
    private var flippedTextureBuffers: TextureBuffers?
    
    private var isDrawing: Bool = false
    
    required init(canvas: CanvasDrawingProtocol) {
        self.canvas = canvas
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.mtlDevice, nodes: flippedTextureNodes)
    }
    required init(canvas: CanvasDrawingProtocol, drawingtoolDiameter: Int? = nil, eraserAlpha: Int? = nil) {
        self.canvas = canvas
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.mtlDevice, nodes: flippedTextureNodes)
        
        self.eraser.setValue(alpha: eraserAlpha, diameter: drawingtoolDiameter)
    }
    func initalizeTextures(textureSize: CGSize) {
        
        if self.textureSize != textureSize {
            self.textureSize = textureSize
            
            self.drawingTexture = canvas.mtlDevice.makeTexture(textureSize)
            self.grayscaleTexture = canvas.mtlDevice.makeTexture(textureSize)
            self.eraserTexture = canvas.mtlDevice.makeTexture(textureSize)
        }
        
        clear()
    }
    
    func drawOnDrawingLayer(with iterator: Iterator<Point>, touchState: TouchState) {
        assert(textureSize != .zero, "Call initalizeTextures() once before here.")
        
        let inverseMatrix = canvas.matrix.getInvertedValue(scale: Aspect.getScaleToFit(canvas.size, to: textureSize))
        let points = Curve.makePoints(iterator: iterator,
                                      matrix: inverseMatrix,
                                      srcSize: canvas.size,
                                      dstSize: textureSize,
                                      endProcessing: touchState == .ended)
        
        guard points.count != 0 else { return }
        
        let pointBuffers = Buffers.makePointBuffers(device: canvas.mtlDevice,
                                                    points: points,
                                                    blurredSize: eraser.blurredSize,
                                                    alpha: eraser.alpha,
                                                    textureSize: textureSize)
        
        Command.drawCurve(buffers: pointBuffers,
                          onGrayscaleTexture: grayscaleTexture,
                          canvas.commandBuffer)
        
        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: (0, 0, 0),
                         result: drawingTexture,
                         canvas.commandBuffer)
        
        Command.copy(dst: eraserTexture,
                     src: canvas.currentLayer,
                     canvas.commandBuffer)
        
        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingTexture,
                                 result: eraserTexture,
                                 canvas.commandBuffer)
        
        isDrawing = true
    }
    func mergeDrawingLayerIntoCurrentLayer() {
        
        Command.copy(dst: eraserTexture,
                     src: canvas.currentLayer,
                     canvas.commandBuffer)
        
        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingTexture,
                                 result: eraserTexture,
                                 canvas.commandBuffer)
        
        Command.copy(dst: canvas.currentLayer,
                     src: eraserTexture,
                     canvas.commandBuffer)
        
        clear()
        
        isDrawing = false
    }
    func clear() {
        
        Command.clear(textures: [eraserTexture,
                                 drawingTexture], canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), canvas.commandBuffer)
    }
}
