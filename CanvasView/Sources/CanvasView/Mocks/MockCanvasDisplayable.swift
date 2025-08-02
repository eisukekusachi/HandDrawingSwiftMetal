//
//  MockCanvasDisplayable.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/05/11.
//

import MetalKit

final class MockCanvasDisplayable: CanvasDisplayable {
    var commandBuffer: MTLCommandBuffer? { nil }

    var displayTexture: MTLTexture? { nil }

    func resetCommandBuffer() {}

    func setNeedsDisplay() {}
}
