//
//  BrushDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

class BrushDrawingLayer: CanvasDrawingLayer {
    
    var brush = Brush()
    
    var textureSize: CGSize = .zero
    
    var canvas: CanvasDrawingProtocol
    
    var currentLayer: [MTLTexture?] {
        return [canvas.currentLayer,
                drawingTexture]
    }
    
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    
    required init(canvas: CanvasDrawingProtocol) {
        self.canvas = canvas
    }
    required init(canvas: CanvasDrawingProtocol, color: UIColor?) {
        self.canvas = canvas
        
        self.brush.setValue(color: color)
    }
    func initalizeTextures(textureSize: CGSize) {
        
        if self.textureSize != textureSize {
            self.textureSize = textureSize
            
            self.drawingTexture = canvas.mtlDevice.makeTexture(textureSize)
            self.grayscaleTexture = canvas.mtlDevice.makeTexture(textureSize)
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
                                                    blurredSize: brush.blurredSize,
                                                    alpha: brush.alpha,
                                                    textureSize: textureSize)
        
        Command.drawCurve(buffers: pointBuffers,
                          onGrayscaleTexture: grayscaleTexture,
                          canvas.commandBuffer)
        
        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: brush.rgb,
                         result: drawingTexture,
                         canvas.commandBuffer)
    }
    func mergeDrawingLayerIntoCurrentLayer() {
        
        Command.merge(dst: canvas.currentLayer,
                      texture: drawingTexture,
                      canvas.commandBuffer)
        
        clear()
    }
    func clear() {
        
        Command.clear(texture: drawingTexture, canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), canvas.commandBuffer)
    }
}
