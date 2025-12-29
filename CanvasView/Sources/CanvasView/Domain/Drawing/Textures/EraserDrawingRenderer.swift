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
    public var displayRealtimeDrawingTexture: Bool {
        _displayRealtimeDrawingTexture
    }
    private var _displayRealtimeDrawingTexture: Bool = false

    private var alpha: Int = 255

    private var diameter: Int = 8

    private var frameSize: CGSize = .zero

    private var textureSize: CGSize?
    private var drawingTexture: MTLTexture?
    private var grayscaleTexture: MTLTexture?
    private var lineDrawnTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers!

    private var displayView: CanvasDisplayable?

    private var renderer: MTLRendering?

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    public init() {}
}

public extension EraserDrawingRenderer {

    func setup(frameSize: CGSize, renderer: MTLRendering, displayView: CanvasDisplayable?) {

        self.displayView = displayView
        self.renderer = renderer

        self.frameSize = frameSize

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

    func getDiameter() -> Int {
        diameter
    }
    func setDiameter(_ diameter: Int) {
        self.diameter = diameter
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

    func onStroke(
        screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform
    ) {
        guard
            let textureSize,
            let displayTextureSize = displayView?.displayTexture?.size
        else { return }

        drawingCurve?.append(
            points: screenTouchPoints.map {
                .init(
                    location: CGAffineTransform.texturePoint(
                        screenPoint: $0.preciseLocation,
                        matrix: matrix,
                        textureSize: textureSize,
                        drawableSize: displayTextureSize,
                        frameSize: frameSize
                    ),
                    brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0,
                    diameter: CGFloat(diameter)
                )
            },
            touchPhase: screenTouchPoints.currentTouchPhase
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
