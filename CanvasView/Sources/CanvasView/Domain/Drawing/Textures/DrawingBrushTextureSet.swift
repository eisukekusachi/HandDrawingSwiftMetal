//
//  CanvasDrawingBrushTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime brush drawing
@MainActor
public final class DrawingBrushTextureSet: DrawingTextureSet {

    private var realtimeDrawingTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering

    private var brushColor: UIColor = .black

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    required public init(renderer: MTLRendering = MTLRenderer.shared) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }
}

public extension DrawingBrushTextureSet {

    func initTextures(_ textureSize: CGSize) {
        self.realtimeDrawingTexture = MTLTextureCreator.makeTexture(label: "realtimeDrawingTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setBrushColor(_ color: UIColor) {
        brushColor = color
    }

    func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        with commandBuffer: MTLCommandBuffer,
        onDrawing: ((MTLTexture) -> Void)?,
        onDrawingCompleted: ((MTLTexture) -> Void)?
    ) {
        updateRealTimeDrawingTexture(
            baseTexture: baseTexture,
            drawingCurve: drawingCurve,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        onDrawing?(realtimeDrawingTexture)

        if drawingCurve.isDrawingFinished {
            drawCurrentTexture(
                texture: realtimeDrawingTexture,
                on: baseTexture,
                with: commandBuffer
            )
            onDrawingCompleted?(realtimeDrawingTexture)
        }
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

extension DrawingBrushTextureSet {

    private func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        on texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.currentCurvePoints,
                alpha: brushColor.alpha,
                textureSize: drawingTexture.size,
                with: device
            ),
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: brushColor.rgb,
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
