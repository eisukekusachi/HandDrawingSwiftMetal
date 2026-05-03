//
//  EraserDrawingRenderer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// Renderer for erasing lines
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

    private var renderer: MTLRendering?

    private var alpha: Int = 255

    private var textureSize: CGSize?
    private var drawingTexture: MTLTexture?
    private var grayscaleTexture: MTLTexture?
    private var lineDrawnTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers!

    private var displayView: CanvasDisplayable?

    /// An iterator that manages a single curve being drawn in realtime
    private var drawingCurve: DrawingCurve?

    /// A scale for rendering short lines.
    /// By scaling the coordinates before calculating the curve and then dividing the result by the same scale,
    /// it becomes possible to draw even extremely short segments.
    private var strokeCurveScale: CGFloat = 1

    public init() {}
}

public extension EraserDrawingRenderer {

    func setup(renderer: MTLRendering) {
        guard let buffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        ) else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(
                    localized: "Failed to create buffers",
                    bundle: .main
                )
            )
            Logger.error(error)
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = renderer
        self.flippedTextureBuffers = buffers
    }

    func initializeTextures(_ textureSize: CGSize) {
        guard
            let renderer,
            let newCommandBuffer = renderer.newCommandBuffer
        else { return }

        self.textureSize = textureSize

        self.drawingTexture = renderer.makeTexture(textureSize, label: "drawingTexture")
        self.grayscaleTexture = renderer.makeTexture(textureSize, label: "grayscaleTexture")
        self.lineDrawnTexture = renderer.makeTexture(textureSize, label: "lineDrawnTexture")

        clearTextures(with: newCommandBuffer)
        newCommandBuffer.commit()
    }

    func setDiameter(_ diameter: Int) {
        self._diameter = diameter
    }

    func setAlpha(_ alpha: Int) {
        self.alpha = alpha
    }

    func beginFingerStroke(curveSpaceScale: CGFloat) {
        strokeCurveScale = curveSpaceScale
        drawingCurve = SmoothDrawingCurve()
    }

    func beginPencilStroke(curveSpaceScale: CGFloat) {
        strokeCurveScale = curveSpaceScale
        drawingCurve = DefaultDrawingCurve()
    }

    func appendStrokePoints(
        strokePoints: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        drawingCurve?.append(
            points: strokePoints.map {
                GrayscaleDotPoint(
                    location: CGPoint(
                        x: $0.location.x * strokeCurveScale,
                        y: $0.location.y * strokeCurveScale
                    ),
                    brightness: $0.brightness,
                    diameter: $0.diameter,
                    blurSize: $0.blurSize
                )
            },
            touchPhase: touchPhase
        )
    }

    func drawStroke(
        baseTexture: MTLTexture?,
        on realtimeDrawingTexture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let drawingCurve,
            let lineDrawnTexture,
            let grayscaleTexture,
            let drawingTexture,
            let baseTexture,
            let realtimeDrawingTexture
        else {
            _displayRealtimeDrawingTexture = false
            return
        }

        let curvePoints = grayscaleCurvePointsInTextureCoordinates(drawingCurve)
        if curvePoints.isEmpty {
            return
        }

        guard
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: curvePoints,
                alpha: alpha,
                textureSize: lineDrawnTexture.size,
                with: renderer.device
            )
        else {
            Logger.error(
                "Failed to create buffers \(curvePoints.count) points, \(lineDrawnTexture.size)"
            )
            _displayRealtimeDrawingTexture = false
            return
        }

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

        _displayRealtimeDrawingTexture = true
    }

    func prepareNextStroke() {
        guard
            let newCommandBuffer = renderer?.newCommandBuffer
        else { return }
        prepareNextStroke(with: newCommandBuffer)
        newCommandBuffer.commit()
    }

    func prepareNextStroke(with commandBuffer: MTLCommandBuffer) {
        clearTextures(with: commandBuffer)
        drawingCurve = nil
        strokeCurveScale = 1
        _displayRealtimeDrawingTexture = false
    }
}

private extension EraserDrawingRenderer {

    func grayscaleCurvePointsInTextureCoordinates(_ curve: DrawingCurve) -> [GrayscaleDotPoint] {
        let inverseScale = 1 / strokeCurveScale

        return curve.curvePoints().map {
            GrayscaleDotPoint(
                location: CGPoint(
                    x: $0.location.x * inverseScale,
                    y: $0.location.y * inverseScale
                ),
                brightness: $0.brightness,
                diameter: $0.diameter,
                blurSize: $0.blurSize
            )
        }
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

extension EraserDrawingRenderer {
    static private let minDiameter: Int = 1
    static private let maxDiameter: Int = 64

    static private let initEraserSize: Int = 8

    public static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    public static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
