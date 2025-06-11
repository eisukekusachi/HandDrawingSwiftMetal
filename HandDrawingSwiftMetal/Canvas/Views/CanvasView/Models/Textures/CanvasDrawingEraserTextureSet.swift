//
//  CanvasDrawingEraserTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for real-time eraser drawing
final class CanvasDrawingEraserTextureSet: CanvasDrawingTextureSet {

    var canvasDrawFinishedPublisher: AnyPublisher<Void, Never> {
        canvasDrawFinishedSubject.eraseToAnyPublisher()
    }

    var drawingSelectedTexture: MTLTexture {
        resultTexture
    }

    private let canvasDrawFinishedSubject = PassthroughSubject<Void, Never>()

    private var eraserAlpha: Int = 255

    private var resultTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var lineDrawnTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required init(renderer: MTLRendering = MTLRenderer.shared) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension CanvasDrawingEraserTextureSet {

    func initTextures(_ textureSize: CGSize) {
        self.resultTexture = MTLTextureCreator.makeTexture(label: "resultTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(label: "lineDrawnTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearDrawingTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setEraserAlpha(_ alpha: Int) {
        eraserAlpha = alpha
    }

    func drawCurvePoints(
        singleCurveIterator: SingleCurveIterator,
        withBackgroundTexture backgroundTexture: MTLTexture?,
        withBackgroundColor backgroundColor: UIColor = .clear,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let backgroundTexture
        else { return }

        drawCurvePointsOnDrawingTexture(
            points: singleCurveIterator.latestCurvePoints,
            sourceTexture: backgroundTexture,
            with: commandBuffer
        )

        drawDrawingTextureWithBackgroundTexture(
            backgroundTexture: backgroundTexture,
            backgroundColor: backgroundColor,
            shouldUpdateSelectedTexture: singleCurveIterator.isDrawingFinished,
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

extension CanvasDrawingEraserTextureSet {

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

    private func drawDrawingTextureWithBackgroundTexture(
        backgroundTexture: MTLTexture,
        backgroundColor: UIColor = .clear,
        shouldUpdateSelectedTexture: Bool,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: drawingTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: resultTexture,
            with: commandBuffer
        )

        if shouldUpdateSelectedTexture {
            renderer.drawTexture(
                texture: backgroundTexture,
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
                on: backgroundTexture,
                with: commandBuffer
            )

            clearDrawingTextures(with: commandBuffer)

            canvasDrawFinishedSubject.send(())
        }
    }

}
