//
//  EraserDrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// A set of textures for realtime eraser drawing
@MainActor
public final class EraserDrawingRenderer: DrawingRenderer {
    public var displayRealtimeDrawingTexture: Bool {
        _displayRealtimeDrawingTexture
    }
    private var _displayRealtimeDrawingTexture: Bool = false

    public var diameter: Int {
        _diameter
    }
    private var _diameter: Int = 8

    public var renderer: MTLRendering? {
        _renderer
    }
    private var _renderer: MTLRendering?

    private var alpha: Int = 255

    private var frameSize: CGSize = .zero

    private var textureSize: CGSize?
    private var drawingTexture: MTLTexture?
    private var grayscaleTexture: MTLTexture?
    private var lineDrawnTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers!

    private var displayView: CanvasDisplayable?


    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    public init() {}
}

public extension EraserDrawingRenderer {

    func setup(renderer: MTLRendering) {

        self._renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        )
    }

    func initializeTextures(textureSize: CGSize) {
        guard
            let renderer,
            let newCommandBuffer = renderer.newCommandBuffer
        else { return }

        self.textureSize = textureSize

        self.drawingTexture = MTLTextureCreator.makeTexture(
            label: "drawingTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
        self.grayscaleTexture = MTLTextureCreator.makeTexture(
            label: "grayscaleTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
        self.lineDrawnTexture = MTLTextureCreator.makeTexture(
            label: "lineDrawnTexture",
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )

        clearTextures(with: newCommandBuffer)
        newCommandBuffer.commit()
    }

    func setFrameSize(_ frameSize: CGSize) {
        self.frameSize = frameSize
    }

    func setDiameter(_ diameter: Int) {
        self._diameter = diameter
    }

    func setAlpha(_ alpha: Int) {
        self.alpha = alpha
    }

    func beginFingerStroke() {
        drawingCurve = SmoothDrawingCurve()
    }

    func beginPencilStroke() {
        drawingCurve = DefaultDrawingCurve()
    }

    func appendStrokePoints(
        strokePoints: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        drawingCurve?.append(
            points: strokePoints,
            touchPhase: touchPhase
        )
    }

    func drawStroke(
        selectedLayerTexture: MTLTexture?,
        on realtimeDrawingTexture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let drawingCurve,
            let lineDrawnTexture,
            let grayscaleTexture,
            let drawingTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.curvePoints(),
                alpha: alpha,
                textureSize: lineDrawnTexture.size,
                with: renderer.device
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
            texture: selectedLayerTexture,
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

        _displayRealtimeDrawingTexture = true
    }

    func prepareNextStroke() {
        guard let newCommandBuffer = renderer?.newCommandBuffer else { return }

        clearTextures(with: newCommandBuffer)
        newCommandBuffer.commit()

        drawingCurve = nil

        _displayRealtimeDrawingTexture = false
    }
}

private extension EraserDrawingRenderer {
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
