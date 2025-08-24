//
//  DrawingEraserTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime eraser drawing
@MainActor
public final class DrawingEraserTextureSet: DrawingTextureSet {

    private var alpha: Int = 255

    private var diameter: Int = 8

    private var textureSize: CGSize!
    private var realtimeDrawingTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var lineDrawnTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private let renderer: MTLRendering

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    public required init(renderer: MTLRendering = MTLRenderer.shared) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }
}

public extension DrawingEraserTextureSet {

    func initTextures(_ textureSize: CGSize) {
        self.textureSize = textureSize
        self.realtimeDrawingTexture = MTLTextureCreator.makeTexture(label: "realtimeDrawingTexture", size: textureSize, with: device)
        self.drawingTexture = MTLTextureCreator.makeTexture(label: "drawingTexture", size: textureSize, with: device)
        self.grayscaleTexture = MTLTextureCreator.makeTexture(label: "grayscaleTexture", size: textureSize, with: device)
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(label: "lineDrawnTexture", size: textureSize, with: device)

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func getDiameter() -> Int {
        diameter
    }
    func setDiameter(_ diameter: Float) {
        self.diameter = DrawingEraserTextureSet.diameterIntValue(diameter)
    }

    func setAlpha(_ alpha: Int) {
        self.alpha = alpha
    }

    func curvePoints(
        _ screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform,
        drawableSize: CGSize,
        frameSize: CGSize
    ) -> [GrayscaleDotPoint] {
        screenTouchPoints.map {
            .init(
                matrix: matrix,
                touchPoint: $0,
                textureSize: textureSize,
                drawableSize: drawableSize,
                frameSize: frameSize,
                diameter: CGFloat(diameter)
            )
        }
    }

    func drawCurve(
        _ drawingCurve: DrawingCurve,
        using baseTexture: MTLTexture,
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
                grayscaleTexture,
                lineDrawnTexture
            ],
            with: commandBuffer
        )
    }
}

extension DrawingEraserTextureSet {

    private func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        on texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.currentCurvePoints,
                alpha: alpha,
                textureSize: lineDrawnTexture.size,
                with: device
            ),
            onGrayscaleTexture: grayscaleTexture,
            with: commandBuffer
        )

        renderer.drawTexture(
            grayscaleTexture: grayscaleTexture,
            color: .init(0, 0, 0),
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
            on: texture,
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

public extension DrawingEraserTextureSet {
    static private let minDiameter: Int = 1
    static private let maxDiameter: Int = 64

    static private let initEraserSize: Int = 8

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
