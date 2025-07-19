//
//  MockCanvasViewRendering.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/05/11.
//

import MetalKit
@testable import HandDrawingSwiftMetal

final class MockCanvasViewRendering: CanvasViewRendering {
    var commandBuffer: MTLCommandBuffer? { nil }

    var renderTexture: MTLTexture? { nil }

    func resetCommandBuffer() {}

    func setNeedsDisplay() {}
}
