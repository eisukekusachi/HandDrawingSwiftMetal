//
//  CanvasDrawingEraserTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime eraser drawing
final class CanvasDrawingEraserTextureSet: CanvasDrawingTextureSet {

    var realtimeDrawingTexturePublisher: AnyPublisher<MTLTexture?, Never> {
        realtimeDrawingTextureSubject.eraseToAnyPublisher()
    }
    private let realtimeDrawingTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    private var eraserAlpha: Int = 255

    private var realtimeDrawingTexture: MTLTexture!
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
        self.realtimeDrawingTexture = MTLTextureCreator.makeTexture(label: "realtimeDrawingTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(label: "lineDrawnTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setEraserAlpha(_ alpha: Int) {
        eraserAlpha = alpha
    }

    func updateRealTimeDrawingTexture(
        singleCurveIterator: SingleCurveIterator,
        baseTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer,
        onDrawingCompleted: (() -> Void)?
    ) {
        updateRealTimeDrawingTexture(
            singleCurveIterator: singleCurveIterator,
            baseTexture: baseTexture,
            with: commandBuffer
        )

        if singleCurveIterator.isDrawingFinished {
            drawCurrentTexture(
                on: baseTexture,
                with: commandBuffer
            )
            onDrawingCompleted?()
        }

        realtimeDrawingTextureSubject.send(realtimeDrawingTexture)
    }

    func clearTextures(with commandBuffer: MTLCommandBuffer) {
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

    private func updateRealTimeDrawingTexture(
        singleCurveIterator: SingleCurveIterator,
        baseTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let baseTexture else { return }

        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: singleCurveIterator.latestCurvePoints,
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
            texture: baseTexture,
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
            on: realtimeDrawingTexture,
            with: commandBuffer
        )
    }

    private func drawCurrentTexture(
        on texture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let texture else { return }

        renderer.drawTexture(
            texture: realtimeDrawingTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: texture,
            with: commandBuffer
        )

        clearTextures(with: commandBuffer)
    }

}
