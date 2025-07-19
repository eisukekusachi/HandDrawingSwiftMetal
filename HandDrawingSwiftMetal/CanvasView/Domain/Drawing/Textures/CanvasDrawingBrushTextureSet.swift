//
//  CanvasDrawingBrushTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime brush drawing
final class CanvasDrawingBrushTextureSet: CanvasDrawingTextureSet {

    var realtimeDrawingTexturePublisher: AnyPublisher<MTLTexture?, Never> {
        realtimeDrawingTextureSubject.eraseToAnyPublisher()
    }
    private let realtimeDrawingTextureSubject = PassthroughSubject<MTLTexture?, Never>()

    private var blushColor: UIColor = .black

    private var realtimeDrawingTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!

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

extension CanvasDrawingBrushTextureSet {

    func initTextures(_ textureSize: CGSize) {
        self.realtimeDrawingTexture = MTLTextureCreator.makeTexture(label: "realtimeDrawingTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setBlushColor(_ color: UIColor) {
        blushColor = color
    }

    func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        with commandBuffer: MTLCommandBuffer,
        onDrawingCompleted: ((MTLTexture) -> Void)?
    ) {
        updateRealTimeDrawingTexture(
            baseTexture: baseTexture,
            drawingCurve: drawingCurve,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        if drawingCurve.isDrawingFinished {
            drawCurrentTexture(
                texture: realtimeDrawingTexture,
                on: baseTexture,
                with: commandBuffer
            )
            onDrawingCompleted?(baseTexture)
        }

        realtimeDrawingTextureSubject.send(realtimeDrawingTexture)
    }

    func clearTextures(with commandBuffer: MTLCommandBuffer) {
        renderer.clearTextures(
            textures: [
                drawingTexture,
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }

}

extension CanvasDrawingBrushTextureSet {

    private func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        on texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.currentCurvePoints,
                alpha: blushColor.alpha,
                textureSize: drawingTexture.size,
                with: device
            ),
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: blushColor.rgb,
            on: drawingTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            texture: baseTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: texture,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: drawingTexture,
            into: texture,
            with: commandBuffer
        )
    }

    private func drawCurrentTexture(
        texture sourceTexture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawTexture(
            texture: sourceTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: destinationTexture,
            with: commandBuffer
        )

        clearTextures(with: commandBuffer)
    }

}
