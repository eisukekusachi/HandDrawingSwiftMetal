//
//  EraserDrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime eraser drawing
@MainActor
public final class EraserDrawingRenderer: DrawingRenderer {

    private var alpha: Int = 255

    private var diameter: Int = 8

    private var frameSize: CGSize = .zero

    private var textureSize: CGSize!
    private var realtimeDrawingTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!
    private var lineDrawnTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private var displayView: CanvasDisplayable?

    private var renderer: MTLRendering?

    public init() {}
}

public extension EraserDrawingRenderer {

    func initialize(frameSize: CGSize, displayView: CanvasDisplayable, renderer: MTLRendering) {
        guard let device = renderer.device else { fatalError("Device is nil") }

        self.displayView = displayView
        self.renderer = renderer

        self.frameSize = frameSize

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

    func initializeTextures(_ textureSize: CGSize) {
        guard let device = renderer?.device else { return }

        self.textureSize = textureSize
        self.realtimeDrawingTexture = MTLTextureCreator.makeTexture(
            label: "realtimeDrawingTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
        self.drawingTexture = MTLTextureCreator.makeTexture(
            label: "drawingTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
        self.grayscaleTexture = MTLTextureCreator.makeTexture(
            label: "grayscaleTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(
            label: "lineDrawnTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }

    func setFrameSize(_ frameSize: CGSize) {
        self.frameSize = frameSize
    }

    func getDiameter() -> Int {
        diameter
    }
    func setDiameter(_ diameter: Int) {
        self.diameter = diameter
    }

    func setAlpha(_ alpha: Int) {
        self.alpha = alpha
    }

    func curvePoints(
        _ screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform,
    ) -> [GrayscaleDotPoint] {
        guard let displayTextureSize = displayView?.displayTexture?.size else { return [] }
        return screenTouchPoints.map {
            .init(
                matrix: matrix,
                touchPoint: $0,
                textureSize: textureSize,
                drawableSize: displayTextureSize,
                frameSize: frameSize,
                diameter: CGFloat(diameter)
            )
        }
    }

    func drawCurve(
        _ drawingCurve: DrawingCurve,
        using baseTexture: MTLTexture,
        onDrawing: ((MTLTexture) -> Void)?,
        onCommandBufferCompleted: (@MainActor () -> Void)?
    ) {
        guard let commandBuffer = displayView?.commandBuffer else { return }

        updateRealTimeDrawingTexture(
            baseTexture: baseTexture,
            drawingCurve: drawingCurve,
            with: commandBuffer
        )

        onDrawing?(realtimeDrawingTexture)

        if drawingCurve.isDrawingFinished {
            drawCurrentTexture(
                texture: realtimeDrawingTexture,
                on: baseTexture,
                with: commandBuffer
            )

            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor in
                    onCommandBufferCompleted?()
                }
            }
        }
    }

    func clearTextures() {
        guard let device = renderer?.device else { return }

        let temporaryRenderCommandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(with: temporaryRenderCommandBuffer)
        temporaryRenderCommandBuffer.commit()
    }
}

private extension EraserDrawingRenderer {

    func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let device = renderer.device,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.currentCurvePoints,
                alpha: alpha,
                textureSize: lineDrawnTexture.size,
                with: device
            )
        else { return }

        renderer.drawGrayPointBuffersWithMaxBlendMode(
            buffers: buffers,
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
            on: realtimeDrawingTexture,
            with: commandBuffer
        )
    }

    func drawCurrentTexture(
        texture sourceTexture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let renderer else { return }

        renderer.drawTexture(
            texture: sourceTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: destinationTexture,
            with: commandBuffer
        )

        clearTextures(with: commandBuffer)
    }

    func clearTextures(with commandBuffer: MTLCommandBuffer) {
        guard let renderer else { return }

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

public extension EraserDrawingRenderer {
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
