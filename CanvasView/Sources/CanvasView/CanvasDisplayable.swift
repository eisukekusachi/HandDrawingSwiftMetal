//
//  CanvasDisplayable.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/06.
//

import MetalKit

@MainActor
public protocol CanvasDisplayable {

    /// Command buffer for a single frame
    var currentFrameCommandBuffer: MTLCommandBuffer? { get }

    var displayTexture: MTLTexture? { get }

    func resetCommandBuffer()

    func setNeedsDisplay()
}
