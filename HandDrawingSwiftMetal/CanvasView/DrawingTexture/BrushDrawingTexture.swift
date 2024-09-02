//
//  BrushDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
/// This class encapsulates a series of actions for drawing a single line on a texture using a brush.
class BrushDrawingTexture: DrawingTextureProtocol {

    var drawingTexture: MTLTexture?

    private var grayscaleTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

}

extension BrushDrawingTexture {

    func initTexture(_ textureSize: CGSize) {
        self.drawingTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.grayscaleTexture = MTKTextureUtils.makeTexture(device, textureSize)

        clearDrawingTexture()
    }

    func getDrawingTexture(includingSelectedTexture texture: MTLTexture) -> [MTLTexture?] {
        [texture, drawingTexture]
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        MTLRenderer.merge(
            texture: drawingTexture,
            into: destinationTexture,
            commandBuffer
        )

        clearDrawingTexture(commandBuffer)
    }

    // Render `selectedLayer.texture` onto `targetTexture`
    // If drawing is in progress, render both `drawingTexture` and `selectedLayer.texture` onto `targetTexture`.
    func drawDrawingTexture(
        includingSelectedTextureLayer selectedLayer: TextureLayer,
        on targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        MTLRenderer.drawTextures(
            [selectedLayer.texture, drawingTexture].compactMap { $0 },
            on: targetTexture,
            commandBuffer
        )
    }

    func clearDrawingTexture() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTexture(commandBuffer)
        commandBuffer.commit()
    }

}

extension BrushDrawingTexture {
    /// First, draw lines in grayscale on the grayscale texture,
    /// then apply the intensity as transparency to colorize the grayscale texture,
    /// and render the colored grayscale texture onto the drawing texture."
    func drawOnBrushDrawingTexture(
        points: [CanvasGrayscaleDotPoint],
        color: UIColor,
        alpha: Int,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let textureSize = drawingTexture?.size,
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

}

extension BrushDrawingTexture {

    private func clearDrawingTexture(_ commandBuffer: MTLCommandBuffer) {
        MTLRenderer.clear(texture: drawingTexture, commandBuffer)
        MTLRenderer.fill(grayscaleTexture, withRGB: (0, 0, 0), commandBuffer)
    }

}
