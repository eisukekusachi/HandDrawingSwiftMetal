//
//  CanvasDrawingTexture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
/// A protocol with the currently drawing texture
protocol CanvasDrawingTexture {
    /// A currently drawing texture
    var drawingTexture: MTLTexture? { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTexture(_ textureSize: CGSize)

    /// Renders `selectedTexture` and `drawingTexture`, then render them onto targetTexture
    func renderDrawingTexture(
        withSelectedTexture selectedTexture: MTLTexture?,
        onto targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    )

    /// Merges the drawing texture into the destination texture
    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    )

    /// Clears all textures
    func clearAllTextures()

}
