//
//  CanvasEraserDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
/// This class encapsulates a series of actions for drawing a single line on a texture using an eraser.
class CanvasEraserDrawingTexture: CanvasDrawingTexture {

    var drawingTexture: MTLTexture?

    private var grayscaleTexture: MTLTexture!
    private var eraserTexture: MTLTexture!

    private var flippedTextureBuffers: TextureBuffers?

    private var isDrawing: Bool = false

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(device: device, nodes: flippedTextureNodes)
    }

}

extension CanvasEraserDrawingTexture {

    func initTexture(_ textureSize: CGSize) {

        self.drawingTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.grayscaleTexture = MTKTextureUtils.makeTexture(device, textureSize)
        self.eraserTexture = MTKTextureUtils.makeTexture(device, textureSize)

        clearDrawingTexture()
    }

    func getDrawingTexture(includingSelectedTexture texture: MTLTexture) -> [MTLTexture?] {
        isDrawing ? [eraserTexture] : [texture]
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard 
            let drawingTexture,
            let flippedTextureBuffers,
            let destinationTexture
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

        clearDrawingTexture(commandBuffer)

        isDrawing = false
    }

    // Render `selectedTexture` onto `targetTexture`
    // If drawing is in progress, render `eraserTexture` onto `targetTexture`.
    func drawDrawingTexture(
        includingSelectedTexture selectedTexture: MTLTexture?,
        on targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let targetTexture,
            let selectedTexture
        else { return }

        MTLRenderer.drawTexture(
            isDrawing ? eraserTexture : selectedTexture,
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

extension CanvasEraserDrawingTexture {
    /// First, draw lines in grayscale on a grayscale texture,
    /// then apply the intensity as transparency to add black color to the grayscale texture,
    /// and render the grayscale texture onto the drawing texture.
    /// After that, blend the drawing texture and the source texture using a blend factor for the eraser to create the eraser texture.
    func drawPointsOnEraserDrawingTexture(
        points: [CanvasGrayscaleDotPoint],
        alpha: Int,
        srcTexture: MTLTexture,
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

}

extension CanvasEraserDrawingTexture {

    private func clearDrawingTexture(_ commandBuffer: MTLCommandBuffer) {
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

}
