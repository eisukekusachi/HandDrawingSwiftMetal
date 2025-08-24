//
//  DrawingTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

/// A protocol for a set of textures for realtime drawing
@MainActor
public protocol DrawingTextureSet {

    /// Initializes the textures for realtime drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    func setDiameter(_ diameter: Float)

    func curvePoints(
        _ screenTouchPoints: [TouchPoint],
        matrix: CGAffineTransform,
        drawableSize: CGSize,
        frameSize: CGSize
    ) -> [GrayscaleDotPoint]

    /// Updates the realtime drawing texture by curve points from the given iterator
    func drawCurve(
        _ drawingCurve: DrawingCurve,
        using baseTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer,
        onDrawing: ((MTLTexture) -> Void)?,
        onDrawingCompleted: ((MTLTexture) -> Void)?
    )

    /// Resets the realtime drawing textures
    func clearTextures(with commandBuffer: MTLCommandBuffer)
}
