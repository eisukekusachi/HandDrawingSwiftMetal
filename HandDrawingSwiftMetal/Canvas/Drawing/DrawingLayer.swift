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

    /// Draws on the drawing texture using the provided touch point iterator and touch state.
    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>,
                              matrix: CGAffineTransform,
                              parameters: DrawingParameters,
                              on dstTexture: MTLTexture,
                              _ touchPhase: UITouch.Phase,
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
