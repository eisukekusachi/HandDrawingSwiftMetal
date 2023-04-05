//
//  EraserDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

class EraserDrawing: Drawing {
    
    var eraser = Eraser()
    
    var textureSize: CGSize = .zero
    
    private var grayscaleTexture: MTLTexture?
    private var drawingTexture: MTLTexture?
    private var eraserTexture: MTLTexture?
    
    private var showEraserTexture: Bool = false
    
    private var flippedTextureBuffers: TextureBuffers?
    
    func initalizeTexturesForDrawing(_ canvas: Canvas, textureSize: CGSize) {
        self.textureSize = textureSize
        
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.mtlDevice, nodes: flippedTextureNodes)
        
        self.grayscaleTexture = Texture.makeTexture(canvas.mtlDevice, textureSize)
        self.drawingTexture = Texture.makeTexture(canvas.mtlDevice, textureSize)
        self.eraserTexture = Texture.makeTexture(canvas.mtlDevice, textureSize)
        
        reset(canvas)
    }
    
    func execute(_ iterator: Iterator<Point>?, endProcessing: Bool, toward canvas: CanvasDrawingProtocol) {
        guard let iterator = iterator else { return }
        assert(drawingTexture != nil, "Call initalizeTexturesForDrawing() after the texture size has been determined.")
        
        let points = Curve.makePoints(iterator: iterator,
                                      matrix: canvas.drawingMatrix,
                                      srcSize: canvas.size,
                                      dstSize: textureSize,
                                      endProcessing: endProcessing)
        
        if points.count == 0 { return }
        
        
        guard let grayscaleTexture = grayscaleTexture,
              let drawingTexture = drawingTexture else { return }
        
        let textureSize = CGSize(width: grayscaleTexture.width, height: grayscaleTexture.height)
        
        let pointBuffers = Buffers.makePointBuffers(device: canvas.mtlDevice,
                                                    points: points,
                                                    blurredSize: eraser.blurredSize,
                                                    alpha: eraser.alpha,
                                                    textureSize: textureSize)
        
        Command.drawCurve(onGrayscaleTexture: grayscaleTexture,
                          buffers: pointBuffers,
                          to: canvas.commandBuffer)
        
        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: (0, 0, 0),
                         result: drawingTexture,
                         to: canvas.commandBuffer)
        
        Command.makeEraserTexture(buffers: flippedTextureBuffers,
                                  currentTexture: canvas.currentTexture,
                                  currentDrawingTexture: drawingTexture,
                                  result: eraserTexture,
                                  to: canvas.commandBuffer)
        
        showEraserTexture = true
    }
    func finishExecuting(_ canvas: CanvasDrawingProtocol) {
        if grayscaleTexture == nil || drawingTexture == nil { return }
        
        Command.makeEraserTexture(buffers: flippedTextureBuffers,
                                  currentTexture: canvas.currentTexture,
                                  currentDrawingTexture: drawingTexture,
                                  result: eraserTexture,
                                  to: canvas.commandBuffer)
        
        Command.copy(src: eraserTexture,
                     dst: canvas.currentTexture,
                     to: canvas.commandBuffer)
        
        reset(canvas)
        
        showEraserTexture = false
    }
    func refresh(_ canvas: CanvasDrawingProtocol) {
        canvas.refreshDisplayTexture(using: [showEraserTexture ? eraserTexture : canvas.currentTexture])
    }
    
    func reset(_ canvas: CanvasDrawingProtocol) {
        
        Command.clear(texture: drawingTexture, to: canvas.commandBuffer)
        Command.clear(texture: eraserTexture, to: canvas.commandBuffer)
        Command.fill(rgb: (0, 0, 0), dst: grayscaleTexture, to: canvas.commandBuffer)
    }
}
