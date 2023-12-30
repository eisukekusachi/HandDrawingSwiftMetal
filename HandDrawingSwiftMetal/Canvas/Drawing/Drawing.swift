//
//  Drawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/10.
//

import MetalKit

/// This protocol encapsulates a series of actions for drawing a single line on a texture.
protocol Drawing {
    var tool: DrawingTool { get }

    var drawingTexture: MTLTexture? { get }

    var textureSize: CGSize { get }

    /// Initializes the textures for drawing with the specified texture size.
    func initTextures(_ textureSize: CGSize)

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              on dstTexture: MTLTexture,
                              _ touchState: TouchState,
                              _ commandBuffer: MTLCommandBuffer)

    /// Merges textures
    func merge(_ srcTexture: MTLTexture?,
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer)
    
    /// Clears the drawing textures.
    func clearDrawingTextures()

    /// Clears the drawing textures.
    func clearDrawingTextures(_ commandBuffer: MTLCommandBuffer)

    func getDrawingTextures(_ texture: MTLTexture) -> [MTLTexture?]
}
