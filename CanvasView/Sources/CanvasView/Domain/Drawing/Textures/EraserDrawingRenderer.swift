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

    public var realtimeDrawingTexture: RealtimeDrawingTexture? {
        _realtimeDrawingTexture
    }
    private var _realtimeDrawingTexture: RealtimeDrawingTexture?

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
        guard let device = renderer.device else { fatalError("Device is nil") }

        self.displayView = displayView
        self.renderer = renderer

        self.frameSize = frameSize

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

    func initializeTextures(_ textureSize: CGSize) throws {
        guard let device = renderer?.device else { return }
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .main),
                message: String(localized: "Texture size is below the minimum", bundle: .main) + ":\(textureSize.width) \(textureSize.height)"
            )
            Logger.error(error)
            throw error
        }

        self.textureSize = textureSize

        self._realtimeDrawingTexture = MTLTextureCreator.makeTexture(
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
        selectedLayerTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let drawingCurve,
            let lineDrawnTexture,
            let grayscaleTexture,
            let drawingTexture,
            let _realtimeDrawingTexture,
            let device = renderer.device,
            let buffers = MTLBuffers.makeGrayscalePointBuffers(
                points: drawingCurve.curvePoints(),
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
            on: _realtimeDrawingTexture,
            with: commandBuffer
        )
    }

    func endStroke(
        selectedLayerTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let _realtimeDrawingTexture
        else { return }

        renderer.drawTexture(
            texture: _realtimeDrawingTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: selectedLayerTexture,
            with: commandBuffer
        )

        clearTextures(with: commandBuffer)
    }

    func prepareNextStroke() {
        guard
            let commandBuffer = renderer?.device?.makeCommandQueue()?.makeCommandBuffer()
        else { return }

        clearTextures(with: commandBuffer)
        commandBuffer.commit()

        drawingCurve = nil
    }

    func updateRealtimeDrawingTexture(_ texture: MTLTexture) {
        guard
            let _realtimeDrawingTexture,
            let commandBuffer = renderer?.device?.makeCommandQueue()?.makeCommandBuffer()
        else { return }

        renderer?.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: _realtimeDrawingTexture,
            with: commandBuffer
        )
        commandBuffer.commit()
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
