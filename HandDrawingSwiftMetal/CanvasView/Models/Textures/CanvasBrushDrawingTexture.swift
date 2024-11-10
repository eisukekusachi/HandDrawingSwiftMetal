//
//  CanvasBrushDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class CanvasBrushDrawingTexture: CanvasDrawingTexture {

    var drawingTexture: MTLTexture?

    private var grayscaleTexture: MTLTexture!

    private var temporaryTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasBrushDrawingTexture {

    func initTexture(_ textureSize: CGSize) {
        self.drawingTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.temporaryTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)

        clearAllTextures()
    }

    /// Renders `drawingTexture` and `selectedTexture` onto `targetTexture`
    func renderDrawingTexture(
        withSelectedTexture selectedTexture: MTLTexture?,
        onto targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let selectedTexture,
            let flippedTextureBuffers,
            let targetTexture
        else { return }

        MTLRenderer.drawTexture(
            texture: selectedTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: targetTexture,
            with: commandBuffer
        )

        MTLRenderer.mergeTextures(
            sourceTexture: drawingTexture,
            destinationTexture: targetTexture,
            temporaryTexture: temporaryTexture,
            temporaryTextureBuffers: flippedTextureBuffers,
            with: commandBuffer
        )
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let flippedTextureBuffers,
            let destinationTexture
        else { return }

        MTLRenderer.mergeTextures(
            sourceTexture: drawingTexture,
            destinationTexture: destinationTexture,
            temporaryTexture: temporaryTexture,
            temporaryTextureBuffers: flippedTextureBuffers,
            with: commandBuffer
        )

        clearAllTextures(commandBuffer)
    }

    func clearAllTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearAllTextures(commandBuffer)
        commandBuffer.commit()
    }

}

extension CanvasBrushDrawingTexture {
    /// First, draw lines in grayscale on the grayscale texture,
    /// then apply the intensity as transparency to colorize the grayscale texture,
    /// and render the colored grayscale texture onto the drawing texture.
    func drawPointsOnBrushDrawingTexture(
        points: [CanvasGrayscaleDotPoint],
        color: UIColor,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let textureSize = drawingTexture?.size,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: color.alpha,
                textureSize: textureSize,
                with: device
            )
        else { return }

        MTLRenderer.drawCurve(
            buffers: buffers,
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        MTLRenderer.colorizeTexture(
            grayscaleTexture: grayscaleTexture,
            color: color.rgb,
            resultTexture: drawingTexture!,
            with: commandBuffer
        )
    }

}

extension CanvasBrushDrawingTexture {

    private func clearAllTextures(_ commandBuffer: MTLCommandBuffer) {
        MTLRenderer.clearTextures(
            textures: [
                drawingTexture,
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }

}
