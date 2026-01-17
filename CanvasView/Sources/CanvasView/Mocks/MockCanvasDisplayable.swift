//
//  MockCanvasDisplayable.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/05/11.
//

import MetalKit

final class MockCanvasDisplayable: CanvasDisplayable {
    var currentFrameCommandBuffer: MTLCommandBuffer? { nil }
    var displayTexture: MTLTexture? { _texture }
    func resetCommandBuffer() {}
    func setNeedsDisplay() {}
    private let _texture: MTLTexture?
    init(texture: MTLTexture?) {
        self._texture = texture
    }
}
