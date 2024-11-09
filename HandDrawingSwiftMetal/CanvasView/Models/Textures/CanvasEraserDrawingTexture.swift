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

    private var flippedTextureBuffers: MTLTextureBuffers?

    private var isDrawing: Bool = false

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasEraserDrawingTexture {

    func initTexture(_ textureSize: CGSize) {

        self.drawingTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.eraserTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)

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

        MTLRenderer.drawTexture(
            texture: destinationTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture,
            buffers: flippedTextureBuffers,
            into: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.drawTexture(
            texture: eraserTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: destinationTexture,
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
            let selectedTexture,
            let flippedTextureBuffers
        else { return }

        MTLRenderer.drawTexture(
            texture: isDrawing ? eraserTexture : selectedTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
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
            ),
            let flippedTextureBuffers
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

        MTLRenderer.drawTexture(
            texture: srcTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.makeEraseTexture(
            sourceTexture: drawingTexture!,
            buffers: flippedTextureBuffers,
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
