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
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: MTLTextureNodes.flippedTextureNodes,
            with: device
        )
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

        MTLRenderer.copyTexture(
            sourceTexture: destinationTexture,
            destinationTexture: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture,
            buffers: flippedTextureBuffers,
            into: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.copyTexture(
            sourceTexture: eraserTexture,
            destinationTexture: destinationTexture,
            with: commandBuffer
        )

        clearDrawingTexture(commandBuffer)

        isDrawing = false
    }

    /// Renders `selectedTexture` onto `targetTexture`
    /// If drawing is in progress, renders `eraserTexture` onto `targetTexture`.
    func renderDrawingTexture(
        withSelectedTexture selectedTexture: MTLTexture?,
        onto targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let targetTexture,
            let selectedTexture
        else { return }

        MTLRenderer.drawTexture(
            texture: isDrawing ? eraserTexture : selectedTexture,
            on: targetTexture,
            with: commandBuffer
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
            color: (0, 0, 0),
            resultTexture: drawingTexture!,
            with: commandBuffer
        )

        MTLRenderer.copyTexture(
            sourceTexture: srcTexture,
            destinationTexture: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture!,
            buffers: flippedTextureBuffers!,
            into: eraserTexture!,
            with: commandBuffer
        )

        isDrawing = true
    }

}

extension CanvasEraserDrawingTexture {

    private func clearDrawingTexture(_ commandBuffer: MTLCommandBuffer) {
        MTLRenderer.clearTextures(
            textures: [
                eraserTexture,
                drawingTexture
            ],
            with: commandBuffer
        )
        MTLRenderer.fillTexture(
            texture: grayscaleTexture,
            withRGB: (0, 0, 0),
            with: commandBuffer
        )
    }

}
