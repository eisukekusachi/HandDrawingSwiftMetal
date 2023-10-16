//
//  EraserDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

class EraserDrawingTexture: DrawingTextureProtocol {
    
    var eraser = Eraser()
    let tool: DrawingTool = .eraser

    var drawingTexture: MTLTexture?

    var currentTextures: [MTLTexture?] {
        isDrawing ? [eraserTexture] : [canvas.currentTexture]
    }

    var textureSize: CGSize = .zero

    var toolDiameter: Int {
        eraser.diameter
    }

    var canvas: Canvas

    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!

    private var flippedTextureBuffers: TextureBuffers?

    private var isDrawing: Bool = false

    required init(canvas: Canvas) {
        self.canvas = canvas
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.device, nodes: flippedTextureNodes)
    }
    required init(canvas: Canvas, diameter: Int? = nil, eraserAlpha: Int? = nil) {
        self.canvas = canvas
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: canvas.device, nodes: flippedTextureNodes)

        self.eraser.setValue(alpha: eraserAlpha, diameter: diameter)
    }
    func initializeTextures(textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize

            self.drawingTexture = canvas.device!.makeTexture(textureSize)
            self.grayscaleTexture = canvas.device!.makeTexture(textureSize)
            self.eraserTexture = canvas.device!.makeTexture(textureSize)
        }

        clearDrawingTextures()
    }

    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>, touchState: TouchState) {
        assert(textureSize != .zero, "Call initalizeTextures() once before here.")

        let inverseMatrix = canvas.matrix.getInvertedValue(scale: Aspect.getScaleToFit(canvas.frame.size, to: textureSize))
        let points = Curve.makePoints(iterator: iterator,
                                      matrix: inverseMatrix,
                                      srcSize: canvas.frame.size,
                                      dstSize: textureSize,
                                      endProcessing: touchState == .ended)

        guard points.count != 0 else { return }

        let pointBuffers = Buffers.makePointBuffers(device: canvas.device,
                                                    points: points,
                                                    blurredDotSize: eraser.blurredDotSize,
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
                     src: canvas.currentTexture,
                     canvas.commandBuffer)

        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingTexture,
                                 result: eraserTexture,
                                 canvas.commandBuffer)

        isDrawing = true

        if touchState == .ended {
            mergeDrawingTexture(into: canvas.currentTexture)
            clearDrawingTextures()
        }
    }
    func mergeDrawingTexture(into dstTexture: MTLTexture) {
        Command.copy(dst: eraserTexture,
                     src: dstTexture,
                     canvas.commandBuffer)

        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingTexture,
                                 result: eraserTexture,
                                 canvas.commandBuffer)

        Command.copy(dst: dstTexture,
                     src: eraserTexture,
                     canvas.commandBuffer)

        clearDrawingTextures()

        isDrawing = false
    }
    func clearDrawingTextures() {
        Command.clear(textures: [eraserTexture,
                                 drawingTexture],
                      canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0),
                     canvas.commandBuffer)
    }
}
