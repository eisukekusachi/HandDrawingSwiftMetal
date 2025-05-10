//
//  MockCanvasViewProtocol.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/05/11.
//

import MetalKit
@testable import HandDrawingSwiftMetal

final class MockCanvasViewProtocol: CanvasViewProtocol {
    var commandBuffer: MTLCommandBuffer? { nil }

    var renderTexture: MTLTexture? { nil }

    func resetCommandBuffer() {}

    func setNeedsDisplay() {}
}
