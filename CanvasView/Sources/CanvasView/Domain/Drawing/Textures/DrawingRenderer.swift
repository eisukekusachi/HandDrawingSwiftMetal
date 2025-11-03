//
//  DrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

public typealias RealtimeDrawingTexture = MTLTexture

/// A protocol that defines a renderer for realtime stroke drawing.
@MainActor
public protocol DrawingRenderer {

    var realtimeDrawingTexture: MTLTexture? { get }

    /// Initializes the textures for realtime drawing with the specified texture size.
    func initializeTextures(_ textureSize: CGSize)

    /// Injects external dependencies `CanvasDisplayable` and `MTLRendering`
    func initialize(frameSize: CGSize, displayView: CanvasDisplayable, renderer: MTLRendering)

    /// Sets the frame size. The frame size changes when the screen rotates or the view layout updates.
    func setFrameSize(_ frameSize: CGSize)

    func startFingerDrawing()

    func startPencilDrawing()

    func appendPoints(
        screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform
    )

    func drawPointsOnRealtimeDrawingTexture(
        using baseTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func finishDrawing(
        targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func prepareNextStroke()
}
