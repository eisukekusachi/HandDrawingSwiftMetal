//
//  CanvasBrushDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class CanvasBrushDrawingTexture: CanvasDrawingTexture {

    var texture: MTLTexture?

    private var grayscaleTexture: MTLTexture!

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
        self.texture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)

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
            sourceTexture: texture,
            destinationTexture: targetTexture,
            with: commandBuffer
        )
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let destinationTexture else { return }

        MTLRenderer.mergeTextures(
            sourceTexture: texture,
            destinationTexture: destinationTexture,
            with: commandBuffer
        )

        clearAllTextures(with: commandBuffer)
    }

    func clearAllTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearAllTextures(with: commandBuffer)
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
            let texture,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: color.alpha,
                textureSize: texture.size,
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
            resultTexture: texture,
            with: commandBuffer
        )
    }

}

extension CanvasBrushDrawingTexture {

    private func clearAllTextures(with commandBuffer: MTLCommandBuffer) {
        MTLRenderer.clearTextures(
            textures: [
                texture,
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }

}
