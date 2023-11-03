//
//  BrushDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class BrushDrawing: DrawingProtocol {
    var brush = Brush()
    let tool: DrawingTool = .brush

    let canvas: Canvas

    var drawingTexture: MTLTexture?

    var currentDrawingTextures: [MTLTexture?] {
        return [canvas.currentTexture,
                drawingTexture]
    }

    var textureSize: CGSize = .zero

    private var grayscaleTexture: MTLTexture!

    required init(canvas: Canvas) {
        self.canvas = canvas
    }

    /// Initializes the textures for drawing with the specified texture size.
    func initializeTextures(_ textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize

            self.drawingTexture = canvas.device!.makeTexture(textureSize)
            self.grayscaleTexture = canvas.device!.makeTexture(textureSize)
        }

        clearDrawingTextures()
    }

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>, touchState: TouchState) {
        assert(textureSize != .zero, "Call initializeTextures() once before here.")

        let inverseMatrix = canvas.matrix.getInvertedValue(scale: Aspect.getScaleToFit(canvas.frame.size, 
                                                                                       to: textureSize))
        let points = Curve.makePoints(iterator: iterator, 
                                      matrix: inverseMatrix,
                                      srcSize: canvas.frame.size,
                                      dstSize: textureSize,
                                      endProcessing: touchState == .ended)

        guard points.count != 0 else { return }

        let pointBuffers = Buffers.makePointBuffers(device: canvas.device!, 
                                                    points: points,
                                                    blurredDotSize: brush.blurredDotSize,
                                                    alpha: brush.alpha,
                                                    textureSize: textureSize)

        Command.drawCurve(buffers: pointBuffers,
                          onGrayscaleTexture: grayscaleTexture,
                          canvas.commandBuffer)

        Command.colorize(grayscaleTexture: grayscaleTexture, 
                         with: brush.rgb,
                         result: drawingTexture,
                         canvas.commandBuffer)

        if touchState == .ended {
            mergeDrawingTexture(into: canvas.currentTexture)
            clearDrawingTextures()
        }
    }

    /// Merges the drawing texture into the destination texture.
    func mergeDrawingTexture(into dstTexture: MTLTexture) {
        Command.merge(dst: dstTexture, 
                      texture: drawingTexture,
                      canvas.commandBuffer)
        
        clearDrawingTextures()
    }

    /// Clears the drawing textures.
    func clearDrawingTextures() {
        Command.clear(texture: drawingTexture, canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), canvas.commandBuffer)
    }
}
