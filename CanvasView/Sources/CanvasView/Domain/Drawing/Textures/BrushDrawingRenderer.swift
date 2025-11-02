//
//  BrushDrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Combine
import MetalKit

/// A set of textures for realtime brush drawing
@MainActor
public final class BrushDrawingRenderer: DrawingRenderer {

    private var color: UIColor = .black

    private var diameter: Int = 8

    private var frameSize: CGSize = .zero

    private var textureSize: CGSize!
    private var realtimeDrawingTexture: MTLTexture!
    private var drawingTexture: MTLTexture!
    private var grayscaleTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers!

    private var displayView: CanvasDisplayable?

    private var renderer: MTLRendering?

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    public init() {}
}

public extension BrushDrawingRenderer {

    var isCurrentlyDrawing: Bool {
        drawingCurve != nil
    }

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

    func setColor(_ color: UIColor) {
        self.color = color
    }

    func startFingerDrawing() {
        drawingCurve = SmoothDrawingCurve()
    }

    func startPencilDrawing() {
        drawingCurve = DefaultDrawingCurve()
    }

    func appendPoints(screenTouchPoints: [TouchPoint], matrix: CGAffineTransform) {
        guard let displayTextureSize = displayView?.displayTexture?.size else { return }
        drawingCurve?.append(
            points: screenTouchPoints.map {
                .init(
                    location: CGAffineTransform.texturePoint(
                        screenPoint: $0.location,
                        matrix: matrix,
                        textureSize: textureSize,
                        drawableSize: displayTextureSize,
                        frameSize: frameSize
                    ),
                    diameter: CGFloat(diameter),
                    brightness: $0.maximumPossibleForce != 0 ? min($0.force, 1.0) : 1.0
                )
            },
            touchPhase: screenTouchPoints.lastTouchPhase
        )
    }

    func drawCurve(
        using baseTexture: MTLTexture,
        onDrawing: ((MTLTexture) -> Void)?,
        onCommandBufferCompleted: (@MainActor () -> Void)?
    ) {
        guard
            let drawingCurve,
            let commandBuffer = displayView?.commandBuffer
        else { return }

        drawCurveOnDrawingTexture(
            drawingCurve: drawingCurve,
            with: commandBuffer
        )

        drawDrawingTextureOnRealTimeDrawingTexture(
            baseTexture: baseTexture,
            with: commandBuffer
        )

        onDrawing?(realtimeDrawingTexture)

        if drawingCurve.isDrawingFinished {
            drawCurrentTexture(
                texture: realtimeDrawingTexture,
                on: baseTexture,
                with: commandBuffer
            )

            prepareNextStroke()
            
            commandBuffer.addCompletedHandler { @Sendable _ in
                Task { @MainActor in
                    onCommandBufferCompleted?()
                }
            }
        }
    }

    func prepareNextStroke() {
        guard
            let commandBuffer = renderer?.device?.makeCommandQueue()?.makeCommandBuffer()
        else { return }

        clearTextures(with: commandBuffer)
        commandBuffer.commit()

        drawingCurve = nil
    }
}

extension BrushDrawingRenderer {

    private func drawCurveOnDrawingTexture(
        drawingCurve: DrawingCurve,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let device = renderer.device,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.currentCurvePoints,
                alpha: color.alpha,
                textureSize: drawingTexture.size,
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
            color: color.rgb,
            on: drawingTexture,
            with: commandBuffer
        )
    }

    private func drawDrawingTextureOnRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer
        else { return }

        renderer.drawTexture(
            texture: baseTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: realtimeDrawingTexture,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: drawingTexture,
            into: realtimeDrawingTexture,
            with: commandBuffer
        )
    }

    private func drawCurrentTexture(
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
                grayscaleTexture
            ],
            with: commandBuffer
        )
    }
}

extension BrushDrawingRenderer {
    static private let minDiameter: Int = 1
    static private let maxDiameter: Int = 64

    static private let initBrushSize: Int = 8

    public static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    public static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
