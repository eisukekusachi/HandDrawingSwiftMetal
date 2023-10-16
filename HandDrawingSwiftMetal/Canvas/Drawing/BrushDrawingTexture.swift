//
//  BrushDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

class BrushDrawingTexture: DrawingTextureProtocol {
    var brush = Brush()
    let tool: DrawingTool = .brush

    let canvas: Canvas

    var drawingTexture: MTLTexture?

    var textureSize: CGSize = .zero

    var toolDiameter: Int {
        brush.diameter
    }

    var currentTextures: [MTLTexture?] {
        return [canvas.currentTexture,
                drawingTexture]
    }

    private var grayscaleTexture: MTLTexture!

    required init(canvas: Canvas) {
        self.canvas = canvas
    }
    func initializeTextures(textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize

            self.drawingTexture = canvas.device!.makeTexture(textureSize)
            self.grayscaleTexture = canvas.device!.makeTexture(textureSize)
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
    func mergeDrawingTexture(into dstTexture: MTLTexture) {
        Command.merge(dst: dstTexture,
                      texture: drawingTexture,
                      canvas.commandBuffer)

        clearDrawingTextures()
    }
    func clearDrawingTextures() {
        Command.clear(texture: drawingTexture, canvas.commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), canvas.commandBuffer)
    }
}
