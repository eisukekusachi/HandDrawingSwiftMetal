//
//  DrawingRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

/// A protocol that defines a renderer for realtime stroke drawing.
@MainActor
public protocol DrawingRenderer {

    /// Initializes the textures for realtime drawing with the specified texture size.
    func initializeTextures(_ textureSize: CGSize)

    /// Injects external dependencies `CanvasDisplayable` and `MTLRendering`
    func initialize(frameSize: CGSize, displayView: CanvasDisplayable, renderer: MTLRendering)

    /// Sets the frame size. The frame size changes when the screen rotates or the view layout updates.
    func setFrameSize(_ frameSize: CGSize)

    func curvePoints(
        _ screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform,
    ) -> [GrayscaleDotPoint]

    /// Updates the realtime drawing texture by curve points from the given iterator
    func drawCurve(
        _ drawingCurve: DrawingCurve,
        using baseTexture: MTLTexture,
        onDrawing: ((MTLTexture) -> Void)?,
        onCommandBufferCompleted: (@MainActor () -> Void)?
    )

    func clearTextures()
}
