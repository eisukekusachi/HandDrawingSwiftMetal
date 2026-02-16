//
//  DrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

public typealias RealtimeDrawingTexture = MTLTexture

/// A protocol that defines a renderer for realtime stroke drawing
@MainActor
public protocol DrawingRenderer: AnyObject {

    var displayRealtimeDrawingTexture: Bool { get }

    var diameter: Int { get }

    func setup(renderer: MTLRendering)

    /// Sets up textures for realtime drawing
    func setupTextures(textureSize: CGSize)

    /// Finger drawing has started
    func beginFingerStroke()

    /// Pen drawing has started
    func beginPencilStroke()

    /// Appends stroke points
    func appendStrokePoints(
        strokePoints: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    )

    /// Draws lines onto a texture
    func drawStroke(
        baseTexture: MTLTexture?,
        on realtimeDrawingTexture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    )

    /// Prepares for the next stroke
    func prepareNextStroke()
    func prepareNextStroke(with commandBuffer: MTLCommandBuffer)
}
