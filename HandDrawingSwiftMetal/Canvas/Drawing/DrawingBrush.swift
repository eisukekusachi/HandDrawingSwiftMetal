//
//  DrawingBrush.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class DrawingBrush: Drawing {
    var tool: DrawingTool = DrawingToolBrush()

    var drawingTexture: MTLTexture?

    var frameSize: CGSize = .zero
    var textureSize: CGSize = .zero

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var grayscaleTexture: MTLTexture!

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize) {
        self.textureSize = textureSize

        self.drawingTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.grayscaleTexture = MTKTextureUtils.makeTexture(device, textureSize)

        clearDrawingTextures()
    }

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              on dstTexture: MTLTexture,
                              _ touchState: TouchState,
                              _ commandBuffer: MTLCommandBuffer) {
        assert(frameSize != .zero, "Set a value for frameSize once before here.")
        assert(textureSize != .zero, "Set a value for textureSize once before here.")
        guard let brush = tool as? DrawingToolBrush else { return }

        let inverseMatrix = matrix.getInvertedValue(scale: Aspect.getScaleToFit(frameSize,
                                                                                to: textureSize))
        let points = Curve.makePoints(iterator: iterator,
                                      matrix: inverseMatrix,
                                      srcSize: frameSize,
                                      dstSize: textureSize,
                                      endProcessing: touchState == .ended)

        guard points.count != 0 else { return }

        let pointBuffers = Buffers.makePointBuffers(device: device,
                                                    points: points,
                                                    blurredDotSize: brush.blurredDotSize,
                                                    alpha: brush.alpha,
                                                    textureSize: textureSize)

        Command.drawCurve(buffers: pointBuffers,
                          onGrayscaleTexture: grayscaleTexture,
                          commandBuffer)

        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: brush.rgb,
                         result: drawingTexture,
                         commandBuffer)

        if touchState == .ended {
            merge(drawingTexture, into: dstTexture, commandBuffer)
        }
    }

    /// Merges the drawing texture into the destination texture.
    func merge(_ srcTexture: MTLTexture?,
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer) {
        Command.merge(srcTexture,
                      into: dstTexture,
                      commandBuffer)
        clearDrawingTextures(commandBuffer)
    }

    func clearDrawingTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(commandBuffer)
        commandBuffer.commit()
    }

    /// Clears the drawing textures.
    func clearDrawingTextures(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(texture: drawingTexture, commandBuffer)
        Command.fill(grayscaleTexture, withRGB: (0, 0, 0), commandBuffer)
    }

    func getDrawingTextures(_ texture: MTLTexture) -> [MTLTexture?] {
        [texture, drawingTexture]
    }
}
