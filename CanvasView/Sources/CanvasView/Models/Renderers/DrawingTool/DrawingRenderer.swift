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

    /// `true` after ``drawStroke`` last completed a full raster pass this stroke
    var displayRealtimeDrawingTexture: Bool { get }

    var diameter: Int { get }

    func setup(renderer: MTLRendering)

    /// Sets up textures for realtime drawing
    func initializeTextures(_ textureSize: CGSize)

    /// Finger drawing has started
    func beginFingerStroke(strokeCurveScale: CGFloat?)

    /// Pen drawing has started
    func beginPencilStroke(strokeCurveScale: CGFloat?)

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

public extension DrawingRenderer {
    func clampedStrokeCurveScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 64)
    }
}
