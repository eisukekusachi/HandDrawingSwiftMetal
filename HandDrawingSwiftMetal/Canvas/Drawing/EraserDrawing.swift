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
        return isDrawing ? [eraserTexture] : [canvas.currentTexture]
    }
    
    private var drawingCellTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!
    
    private var flippedTextureBuffers: TextureBuffers?
    
    private var isDrawing: Bool = false
    
    required init(canvas: CanvasDrawingProtocol) {
        self.canvas = canvas
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.mtlDevice, nodes: flippedTextureNodes)
    }
    func initalizeTextures(textureSize: CGSize) {
        
        if self.textureSize != textureSize {
            self.textureSize = textureSize
            
            self.drawingCellTexture = canvas.mtlDevice.makeTexture(textureSize)
            self.grayscaleTexture = canvas.mtlDevice.makeTexture(textureSize)
            self.eraserTexture = canvas.mtlDevice.makeTexture(textureSize)
        }
        
        clear()
    }
    
    func drawOnCellTexture(_ iterator: Iterator<Point>, touchState: TouchState) {
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
                          to: canvas.commandBuffer)
        
        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: (0, 0, 0),
                         result: drawingCellTexture,
                         to: canvas.commandBuffer)
        
        Command.copy(src: canvas.currentTexture,
                     dst: eraserTexture,
                     to: canvas.commandBuffer)
        
        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingCellTexture,
                                 result: eraserTexture,
                                 to: canvas.commandBuffer)
        
        isDrawing = true
    }
    func mergeCellTextureIntoCurrentLayer() {
        
        Command.copy(src: canvas.currentTexture,
                     dst: eraserTexture,
                     to: canvas.commandBuffer)
        
        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingCellTexture,
                                 result: eraserTexture,
                                 to: canvas.commandBuffer)
        
        Command.copy(src: eraserTexture,
                     dst: canvas.currentTexture,
                     to: canvas.commandBuffer)
        
        clear()
        
        isDrawing = false
    }
    func clear() {
        
        Command.clear(textures: [eraserTexture,
                                 drawingCellTexture], to: canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), to: canvas.commandBuffer)
    }
}
