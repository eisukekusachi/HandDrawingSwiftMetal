//
//  CanvasEraserDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit
import Combine

/// A class used for real-time drawing on a texture using an eraser
final class CanvasEraserDrawingTexture: CanvasDrawingTexture {

    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> {
        canvasDrawFinishedSubject.eraseToAnyPublisher()
    }

    private let canvasDrawFinishedSubject = PassthroughSubject<Void, Never>()

    private var eraserAlpha: Int = 255

    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var lineDrawnTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init(renderer: MTLRendering) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasEraserDrawingTexture {

    func initTextures(_ textureSize: CGSize) {
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(label: "lineDrawnTexture", size: textureSize, with: device)

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(with: commandBuffer)
        commandBuffer.commit()
    }

    func setEraserAlpha(_ alpha: Int) {
        eraserAlpha = alpha
    }

    func drawCurvePointsUsingSelectedTexture(
        drawingCurvePoints: CanvasDrawingCurvePoints,
        selectedTexture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        drawCurvePointsOnDrawingTexture(
            points: drawingCurvePoints.makeCurvePointsFromIterator(),
            sourceTexture: selectedTexture,
            with: commandBuffer
        )

        drawDrawingTextureWithSelectedTexture(
            selectedTexture: selectedTexture,
            shouldUpdateSelectedTexture: drawingCurvePoints.isDrawingFinished,
            on: destinationTexture,
            with: commandBuffer
        )
    }

    func clearDrawingTextures(with commandBuffer: MTLCommandBuffer) {
        renderer.clearTextures(
            textures: [
                drawingTexture,
                grayscaleTexture,
                lineDrawnTexture
            ],
            with: commandBuffer
        )
    }

}

extension CanvasEraserDrawingTexture {

    private func drawCurvePointsOnDrawingTexture(
        points: [GrayscaleDotPoint],
        sourceTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: points,
                alpha: eraserAlpha,
                textureSize: lineDrawnTexture.size,
                with: device
            ),
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: (0, 0, 0),
            on: lineDrawnTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            texture: sourceTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: drawingTexture,
            with: commandBuffer
        )

        renderer.subtractTextureWithEraseBlendMode(
            texture: lineDrawnTexture,
            buffers: flippedTextureBuffers,
            from: drawingTexture,
            with: commandBuffer
        )
    }

    private func drawDrawingTextureWithSelectedTexture(
        selectedTexture: MTLTexture,
        shouldUpdateSelectedTexture: Bool,
        on targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: drawingTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: targetTexture,
            with: commandBuffer
        )

        if shouldUpdateSelectedTexture {
            renderer.drawTexture(
                texture: selectedTexture,
                buffers: flippedTextureBuffers,
                withBackgroundColor: .clear,
                on: drawingTexture,
                with: commandBuffer
            )

            renderer.subtractTextureWithEraseBlendMode(
                texture: lineDrawnTexture,
                buffers: flippedTextureBuffers,
                from: drawingTexture,
                with: commandBuffer
            )

            renderer.drawTexture(
                texture: drawingTexture,
                buffers: flippedTextureBuffers,
                withBackgroundColor: .clear,
                on: selectedTexture,
                with: commandBuffer
            )

            clearDrawingTextures(with: commandBuffer)

            canvasDrawFinishedSubject.send(())
        }
    }

}
