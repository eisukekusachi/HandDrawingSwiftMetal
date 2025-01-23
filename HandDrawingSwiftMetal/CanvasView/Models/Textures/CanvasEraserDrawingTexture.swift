//
//  CanvasEraserDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
/// This class encapsulates a series of actions for drawing a single line on a texture using an eraser.
class CanvasEraserDrawingTexture: CanvasDrawingTexture {

    var texture: MTLTexture?

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

        self.texture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        self.eraserTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)

        clearAllTextures()
    }

    /// Renders `selectedTexture` onto `targetTexture`
    /// If drawing is in progress, renders `eraserTexture` onto `targetTexture`
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

        MTLRenderer.shared.drawTexture(
            texture: isDrawing ? eraserTexture : selectedTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: targetTexture,
            with: commandBuffer
        )
    }

    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let flippedTextureBuffers,
            let destinationTexture
        else { return }

        MTLRenderer.shared.drawTexture(
            texture: destinationTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.shared.mergeTextureWithEraseBlendMode(
            texture: texture,
            buffers: flippedTextureBuffers,
            on: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.shared.drawTexture(
            texture: eraserTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: destinationTexture,
            with: commandBuffer
        )

        clearAllTextures(with: commandBuffer)

        isDrawing = false
    }

    func clearAllTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearAllTextures(with: commandBuffer)
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
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: alpha,
                textureSize: texture.size,
                with: device
            ),
            let flippedTextureBuffers
        else { return }

        MTLRenderer.shared.drawGrayPointBuffersWithMaxBlendMode(
            buffers: buffers,
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        MTLRenderer.shared.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: (0, 0, 0),
            on: texture,
            with: commandBuffer
        )

        MTLRenderer.shared.drawTexture(
            texture: srcTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: eraserTexture,
            with: commandBuffer
        )

        MTLRenderer.shared.mergeTextureWithEraseBlendMode(
            texture: texture,
            buffers: flippedTextureBuffers,
            on: eraserTexture!,
            with: commandBuffer
        )

        isDrawing = true
    }

}

extension CanvasEraserDrawingTexture {

    private func clearAllTextures(with commandBuffer: MTLCommandBuffer) {
        MTLRenderer.shared.clearTextures(
            textures: [
                texture,
                eraserTexture,
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }

}
