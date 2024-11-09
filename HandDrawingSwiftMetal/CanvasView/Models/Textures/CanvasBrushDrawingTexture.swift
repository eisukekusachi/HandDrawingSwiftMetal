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

        clearDrawingTexture()
    }

    func getDrawingTexture(includingSelectedTexture texture: MTLTexture) -> [MTLTexture?] {
        [texture, drawingTexture]
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
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

        clearDrawingTexture(commandBuffer)
    }

    /// Renders `selectedTexture` onto `targetTexture`.
    /// If a drawing operation is in progress, it renders both `drawingTexture` and `selectedTexture` onto `targetTexture`.
    func renderDrawingTexture(
        withSelectedTexture selectedTexture: MTLTexture?,
        onto targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textures = [selectedTexture, drawingTexture].compactMap { $0 }

        guard
            textures.count != 0,
            let targetTexture,
            let flippedTextureBuffers,
            let firstTexture = textures.first
        else { return }

        for i in 0 ..< textures.count {
            if i == 0 {
                MTLRenderer.drawTexture(
                    texture: firstTexture,
                    buffers: flippedTextureBuffers,
                    withBackgroundColor: .clear,
                    on: targetTexture,
                    with: commandBuffer
                )

            } else {
                MTLRenderer.mergeTextures(
                    sourceTexture: textures[i],
                    destinationTexture: targetTexture,
                    temporaryTexture: temporaryTexture,
                    temporaryTextureBuffers: flippedTextureBuffers,
                    with: commandBuffer
                )
            }
        }
    }

    func clearDrawingTexture() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTexture(commandBuffer)
        commandBuffer.commit()
    }

}

extension CanvasBrushDrawingTexture {
    /// First, draw lines in grayscale on the grayscale texture,
    /// then apply the intensity as transparency to colorize the grayscale texture,
    /// and render the colored grayscale texture onto the drawing texture."
    func drawPointsOnBrushDrawingTexture(
        points: [CanvasGrayscaleDotPoint],
        color: UIColor,
        alpha: Int,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let textureSize = drawingTexture?.size,
            let pointBuffers = MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: alpha,
                textureSize: textureSize,
                with: device
            )
        else { return }

        MTLRenderer.drawCurve(
            buffers: pointBuffers,
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

    private func clearDrawingTexture(_ commandBuffer: MTLCommandBuffer) {
        MTLRenderer.clearTexture(
            texture: drawingTexture,
            with: commandBuffer
        )
        MTLRenderer.fillTexture(
            texture: grayscaleTexture,
            withRGB: (0, 0, 0),
            with: commandBuffer
        )
    }

}
