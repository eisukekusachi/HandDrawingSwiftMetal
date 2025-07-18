//
//  CanvasViewRendering.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/06.
//

import MetalKit

protocol CanvasViewRendering {
    var commandBuffer: MTLCommandBuffer? { get }

    var renderTexture: MTLTexture? { get }

    func resetCommandBuffer()

    func setNeedsDisplay()
}
