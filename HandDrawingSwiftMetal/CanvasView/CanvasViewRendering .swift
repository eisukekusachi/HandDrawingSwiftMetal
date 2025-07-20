//
//  CanvasDisplayable.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/06.
//

import MetalKit

protocol CanvasDisplayable {
    var commandBuffer: MTLCommandBuffer? { get }

    var displayTexture: MTLTexture? { get }

    func resetCommandBuffer()

    func setNeedsDisplay()
}
