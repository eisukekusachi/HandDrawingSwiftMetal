//
//  DrawingEraser.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This class encapsulates a series of actions for drawing a single line on a texture using an eraser.
class DrawingEraser: DrawingProtocol {
    var tool: DrawingTool = DrawingToolEraser()

    var drawingTexture: MTLTexture?

    var frameSize: CGSize = .zero
    var textureSize: CGSize = .zero

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!

    private var flippedTextureBuffers: TextureBuffers?

    private var isDrawing: Bool = false

    required init() {
        self.flippedTextureBuffers = Buffers.makeTextureBuffers(device: device, nodes: flippedTextureNodes)
    }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize

            self.drawingTexture = device.makeTexture(textureSize)
            self.grayscaleTexture = device.makeTexture(textureSize)
            self.eraserTexture = device.makeTexture(textureSize)
        }

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(commandBuffer)
        commandBuffer.commit()
    }

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              on dstTexture: MTLTexture,
                              _ touchState: TouchState,
                              _ commandBuffer: MTLCommandBuffer) {
        assert(frameSize != .zero, "Set a value for frameSize once before here.")
        assert(textureSize != .zero, "Set a value for textureSize once before here.")
        guard let eraser = tool as? DrawingToolEraser else { return }

        let inverseMatrix = matrix.getInvertedValue(scale: Aspect.getScaleToFit(frameSize, to: textureSize))
        let points = Curve.makePoints(iterator: iterator,
                                      matrix: inverseMatrix,
                                      srcSize: frameSize,
                                      dstSize: textureSize,
                                      endProcessing: touchState == .ended)

        guard points.count != 0 else { return }

        let pointBuffers = Buffers.makePointBuffers(device: device,
                                                    points: points,
                                                    blurredDotSize: eraser.blurredDotSize,
                                                    alpha: eraser.alpha,
                                                    textureSize: textureSize)

        Command.drawCurve(buffers: pointBuffers,
                          onGrayscaleTexture: grayscaleTexture,
                          commandBuffer)

        Command.colorize(grayscaleTexture: grayscaleTexture,
                         with: (0, 0, 0),
                         result: drawingTexture,
                         commandBuffer)

        Command.copy(dst: eraserTexture,
                     src: dstTexture,
                     commandBuffer)

        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: drawingTexture,
                                 result: eraserTexture,
                                 commandBuffer)

        isDrawing = true

        if touchState == .ended {
            merge(drawingTexture, into: dstTexture, commandBuffer)
        }
    }

    /// Merges the drawing texture into the destination texture.
    func merge(_ srcTexture: MTLTexture?,
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer) {
        Command.copy(dst: eraserTexture, src: dstTexture, commandBuffer)

        Command.makeEraseTexture(buffers: flippedTextureBuffers,
                                 src: srcTexture,
                                 result: eraserTexture,
                                 commandBuffer)

        Command.copy(dst: dstTexture,
                     src: eraserTexture,
                     commandBuffer)

        clearDrawingTextures(commandBuffer)

        isDrawing = false
    }

    /// Clears the drawing textures.
    func clearDrawingTextures(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(textures: [eraserTexture,
                                 drawingTexture],
                      commandBuffer)
        Command.fill(grayscaleTexture,
                     withRGB: (0, 0, 0),
                     commandBuffer)
    }

    func getDrawingTextures(_ texture: MTLTexture) -> [MTLTexture?] {
        isDrawing ? [eraserTexture] : [texture]
    }
}
