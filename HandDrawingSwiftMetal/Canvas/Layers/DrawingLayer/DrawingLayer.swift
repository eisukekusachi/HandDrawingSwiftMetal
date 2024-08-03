//
//  DrawingLayer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

/// protocol for managing the currently drawing layer
protocol DrawingLayer {

    var drawingTexture: MTLTexture? { get }

    var textureSize: CGSize { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Merges textures
    func mergeDrawingTexture(
        into destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    )

    /// Clears the drawing textures.
    func clearDrawingTextures()

    /// Clears the drawing textures.
    func clearDrawingTextures(_ commandBuffer: MTLCommandBuffer)

    func getDrawingTextures(_ texture: MTLTexture) -> [MTLTexture?]
}
