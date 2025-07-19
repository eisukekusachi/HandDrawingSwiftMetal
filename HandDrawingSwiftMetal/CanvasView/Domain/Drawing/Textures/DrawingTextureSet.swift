//
//  DrawingTextureSet.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import Combine
import MetalKit

/// A protocol for a set of textures for realtime drawing
protocol DrawingTextureSet {

    /// Initializes the textures for realtime drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Updates the realtime drawing texture by curve points from the given iterator
    func updateRealTimeDrawingTexture(
        baseTexture: MTLTexture,
        drawingCurve: DrawingCurve,
        with commandBuffer: MTLCommandBuffer,
        onDrawing: ((MTLTexture) -> Void)?,
        onDrawingCompleted: ((MTLTexture) -> Void)?
    )

    /// Resets the realtime drawing textures
    func clearTextures(with commandBuffer: MTLCommandBuffer)
}
