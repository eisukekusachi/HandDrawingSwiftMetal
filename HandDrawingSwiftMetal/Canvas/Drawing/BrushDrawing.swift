//
//  BrushDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation
import MetalKit

class BrushDrawing: Drawing {
    
    var brush = Brush()
    
    var textureSize: CGSize = .zero
    
    private var grayscaleTexture: MTLTexture?
    private var drawingTexture: MTLTexture?
    
    func initalizeTexturesForDrawing(_ canvas: Canvas, textureSize: CGSize) {
        self.textureSize = textureSize
        
        self.grayscaleTexture = Texture.makeTexture(canvas.mtlDevice, textureSize)
        self.drawingTexture = Texture.makeTexture(canvas.mtlDevice, textureSize)
        
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
                                                    blurredSize: brush.blurredSize,
                                                    alpha: brush.alpha,
                                                    textureSize: textureSize)
        
        Command.drawCurve(onGrayscaleTexture: grayscaleTexture,
                          buffers: pointBuffers,
                          to: canvas.commandBuffer)
        
        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: brush.rgb,
                         result: drawingTexture,
                         to: canvas.commandBuffer)
    }
    func finishExecuting(_ canvas: CanvasDrawingProtocol) {
        if grayscaleTexture == nil || drawingTexture == nil { return }
        
        Command.merge(dst: canvas.currentTexture,
                      texture: drawingTexture,
                      to: canvas.commandBuffer)
        
        reset(canvas)
    }
    func refresh(_ canvas: CanvasDrawingProtocol) {
        canvas.refreshDisplayTexture(using: [canvas.currentTexture, drawingTexture])
    }
    
    func reset(_ canvas: CanvasDrawingProtocol) {
        
        Command.clear(texture: drawingTexture, to: canvas.commandBuffer)
        Command.fill(rgb: (0, 0, 0), dst: grayscaleTexture, to: canvas.commandBuffer)
    }
}
