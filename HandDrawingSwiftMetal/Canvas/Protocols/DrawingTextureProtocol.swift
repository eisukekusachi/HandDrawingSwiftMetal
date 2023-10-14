//
//  DrawingTextureProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import MetalKit

protocol DrawingTextureProtocol {
    var tool: DrawingTool { get }

    var drawingTexture: MTLTexture? { get }

    var currentTextures: [MTLTexture?] { get }

    var toolDiameter: Int { get }
    var textureSize: CGSize { get }

    func initalizeTextures(textureSize: CGSize)

    func clearDrawingTextures()

    func drawOnDrawingTexture(with iterator: Iterator<TouchPoint>, touchState: TouchState)
    func mergeDrawingTexture(into dstTexture: MTLTexture)
}
