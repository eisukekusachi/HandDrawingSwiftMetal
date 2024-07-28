//
//  DrawingBrushLayer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class DrawingBrushLayer: DrawingLayer {

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

    /// First, draw lines in grayscale on the grayscale texture,
    /// then apply the intensity as transparency to colorize the grayscale texture,
    /// and render the colored grayscale texture onto the drawing texture."
    func drawOnBrushDrawingTexture(
        points: [GrayscaleTexturePoint],
        color: UIColor,
        alpha: Int,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let pointBuffers = MTLBuffers.makeGrayscalePointBuffers(
                device: device,
                points: points,
                alpha: alpha,
                textureSize: textureSize
            )
        else { return }

        MTLRenderer.drawCurve(
            buffers: pointBuffers,
            onGrayscaleTexture: grayscaleTexture,
            commandBuffer
        )

        MTLRenderer.colorize(
            grayscaleTexture: grayscaleTexture,
            with: color.rgb,
            result: drawingTexture!,
            commandBuffer
        )
    }

    /// First, draw lines in grayscale on the grayscale texture,
    /// then apply the intensity as transparency to colorize the grayscale texture,
    /// and render the colored grayscale texture onto the drawing texture."
    func drawOnDrawingTexture(
        segment: LineSegment,
        _ commandBuffer: MTLCommandBuffer
    ) {
        let pointBuffers = Buffers.makeGrayscalePointBuffers(
            device: device,
            points: segment.dotPoints,
            blurredDotSize: segment.parameters.dotSize,
            alpha: segment.parameters.alpha,
            textureSize: textureSize
        )

        Command.drawCurve(
            buffers: pointBuffers,
            onGrayscaleTexture: grayscaleTexture,
            commandBuffer
        )

        Command.colorize(
            grayscaleTexture: grayscaleTexture,
            with: (segment.parameters.brushColor ?? .black).rgb,
            result: drawingTexture,
            commandBuffer
        )
    }

    /// Merges the drawing texture into the destination texture.
    func mergeDrawingTexture(
        into dstTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        Command.merge(
            texture: drawingTexture,
            into: dstTexture,
            commandBuffer
        )

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
