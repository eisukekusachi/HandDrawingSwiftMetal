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

    var textureSize: CGSize = .zero

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!

    private var flippedTextureBuffers: TextureBuffers?

    private var isDrawing: Bool = false

    required init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(device: device, nodes: flippedTextureNodes)
    }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize) {
        self.textureSize = textureSize

        self.drawingTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.grayscaleTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.eraserTexture = MTKTextureUtils.makeTexture(device, textureSize)

        clearDrawingTextures()
    }

    /// First, draw lines in grayscale on a grayscale texture,
    /// then apply the intensity as transparency to add black color to the grayscale texture,
    /// and render the grayscale texture onto the drawing texture.
    /// After that, blend the drawing texture and the source texture using a blend factor for the eraser to create the eraser texture.
    func drawOnEraserDrawingTexture(
        points: [GrayscaleTexturePoint],
        alpha: Int,
        srcTexture: MTLTexture,
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
            with: (0, 0, 0),
            result: drawingTexture!,
            commandBuffer
        )

        MTLRenderer.copy(
            sourceTexture: srcTexture,
            destinationTexture: eraserTexture,
            commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture!,
            buffers: flippedTextureBuffers!,
            into: eraserTexture!,
            commandBuffer
        )

        isDrawing = true
    }

    /// Merges the eraser texture into the destination texture.
    func mergeDrawingTexture(
        into destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard 
            let drawingTexture,
            let flippedTextureBuffers
        else { return }

        MTLRenderer.copy(
            sourceTexture: destinationTexture,
            destinationTexture: eraserTexture,
            commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture,
            buffers: flippedTextureBuffers,
            into: eraserTexture,
            commandBuffer
        )

        MTLRenderer.copy(
            sourceTexture: eraserTexture,
            destinationTexture: destinationTexture,
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
        MTLRenderer.clear(
            textures: [
                eraserTexture,
                drawingTexture
            ],
            commandBuffer
        )
        MTLRenderer.fill(
            grayscaleTexture,
            withRGB: (0, 0, 0),
            commandBuffer
        )
    }

    func getDrawingTextures(_ texture: MTLTexture) -> [MTLTexture?] {
        isDrawing ? [eraserTexture] : [texture]
    }

}
