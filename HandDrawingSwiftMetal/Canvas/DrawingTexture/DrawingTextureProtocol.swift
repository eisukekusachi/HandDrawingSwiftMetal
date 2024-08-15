//
//  DrawingTextureProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit
/// A layer protocol with the currently drawing texture
protocol DrawingTextureProtocol {
    /// Currently drawing texture
    var drawingTexture: MTLTexture? { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTexture(_ textureSize: CGSize)

    /// Merges the drawing texture into the destination texture
    func mergeDrawingTexture(
        into destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    )
    
    /// Returns an array containing the currently selected texture and the currently drawing texture
    func getDrawingTexture(includingSelectedTexture texture: MTLTexture) -> [MTLTexture?]

    /// Clears  the drawing textures.
    func clearDrawingTexture()

}
