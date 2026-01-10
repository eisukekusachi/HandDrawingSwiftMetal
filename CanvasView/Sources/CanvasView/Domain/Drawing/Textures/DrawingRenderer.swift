//
//  DrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

public typealias RealtimeDrawingTexture = MTLTexture

/// A protocol that defines a renderer for realtime stroke drawing.
@MainActor
public protocol DrawingRenderer {

    var displayRealtimeDrawingTexture: Bool { get }

    /// Configures external dependencies
    func setup(frameSize: CGSize, renderer: MTLRendering, displayView: CanvasDisplayable?)

    /// Initializes the textures for realtime drawing
    func initializeTextures(textureSize: CGSize)

    /// Sets the frame size. The frame size changes when the screen rotates or the view layout updates.
    func setFrameSize(_ frameSize: CGSize)

    /// Finger drawing has started
    func beginFingerStroke()

    /// Pen drawing has started
    func beginPencilStroke()

    /// Called on every drag event
    func onStroke(
        screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform
    )

    /// Called during drawing
    func drawStroke(
        selectedLayerTexture: MTLTexture?,
        on realtimeDrawingTexture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    )

    /// Prepare for the next stroke
    func prepareNextStroke()
}
