//
//  DrawingEraserLayer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This class encapsulates a series of actions for drawing a single line on a texture using an eraser.
class DrawingEraserLayer: DrawingLayer {

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
        self.textureSize = textureSize

        self.drawingTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.grayscaleTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.eraserTexture = MTKTextureUtils.makeTexture(device, textureSize)

        clearDrawingTextures()
    }

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(
        segment: LineSegment,
        on dstTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard let dstTexture else { return }

        let pointBuffers = Buffers.makePointBuffers(device: device,
                                                    points: segment.dotPoints,
                                                    blurredDotSize: segment.parameters.dotSize,
                                                    alpha: segment.parameters.alpha,
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
    }

    /// Merges the drawing texture into the destination texture.
    func mergeDrawingTexture(
        into dstTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        Command.copy(
            dst: eraserTexture,
            src: dstTexture, commandBuffer
        )

        Command.makeEraseTexture(
            buffers: flippedTextureBuffers,
            src: drawingTexture,
            result: eraserTexture,
            commandBuffer
        )

        Command.copy(
            dst: dstTexture,
            src: eraserTexture,
            commandBuffer
        )

        clearDrawingTextures(commandBuffer)

        isDrawing = false
    }

    func clearDrawingTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(commandBuffer)
        commandBuffer.commit()
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