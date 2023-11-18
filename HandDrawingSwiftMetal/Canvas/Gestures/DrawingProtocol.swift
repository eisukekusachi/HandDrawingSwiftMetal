//
//  DrawingProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

/// This protocol encapsulates a series of actions for drawing a single line on a texture.
protocol DrawingProtocol {
    var drawingTool: DrawingTool { get }

    var currentDrawingTextures: [MTLTexture?] { get }

    var drawingTexture: MTLTexture? { get }

    var textureSize: CGSize { get }

    func initializeTextures(_ textureSize: CGSize)

    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>, touchState: TouchState)
    func mergeDrawingTexture(into dstTexture: MTLTexture)

    func clearDrawingTextures()
}
