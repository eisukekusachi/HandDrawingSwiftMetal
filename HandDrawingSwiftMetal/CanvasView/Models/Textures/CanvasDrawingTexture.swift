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

    /// Returns an array containing the currently selected texture and the currently drawing texture
    func getDrawingTexture(includingSelectedTexture texture: MTLTexture) -> [MTLTexture?]

    /// Renders `selectedTexture` and `drawingTexture`, then render them onto targetTexture
    func renderDrawingTexture(
        withSelectedTexture selectedTexture: MTLTexture?,
        onto targetTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    )

    /// Merges the drawing texture into the destination texture
    func mergeDrawingTexture(
        into destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    )

    /// Clears  the drawing textures.
    func clearDrawingTexture()

}
