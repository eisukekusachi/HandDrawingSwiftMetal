//
//  DrawingRenderer.swift
//  CanvasView
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
    func initializeTextures(_ textureSize: CGSize)

    /// Finger drawing has started.
    /// - Parameter curveSpaceScale: Multiplier applied to texture-space stroke coordinates before Bézier sampling for this stroke (reversed when rasterizing). Use ``1`` when no extra scaling is needed.
    func beginFingerStroke(curveSpaceScale: CGFloat)

    /// Pen drawing has started. See ``beginFingerStroke(curveSpaceScale:)``.
    func beginPencilStroke(curveSpaceScale: CGFloat)

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
