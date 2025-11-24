//
//  MockMTLRenderer.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import Metal
import UIKit

final class MockMTLRenderer: MTLRendering, @unchecked Sendable {

    var callHistory: [String] = []
    let device: MTLDevice?


    var newCommandBuffer: MTLCommandBuffer? {
        commandQueue?.makeCommandBuffer()
    }

    private let commandQueue: MTLCommandQueue?

    init() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device!.makeCommandQueue()
    }

    private func recordCall(_ function: StaticString = #function) {
        callHistory.append("\(function)")
    }

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        frameSize: CGSize,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor?,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: IntRGB,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func copyTexture(
        srcTexture: any MTLTexture,
        dstTexture: any MTLTexture,
        with commandBuffer: any MTLCommandBuffer
    ) {
        recordCall()
    }

    func subtractTextureWithEraseBlendMode(
        texture: any MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: any MTLTexture,
        with commandBuffer: any MTLCommandBuffer
    ) {
        recordCall()
    }

    func fillColor(
        texture: MTLTexture,
        withRGB rgb: IntRGB,
        with commandBuffer: any MTLCommandBuffer
    ) {
        recordCall()
    }

    func fillColor(
        texture: MTLTexture,
        withRGBA rgba: IntRGBA,
        with commandBuffer: any MTLCommandBuffer
    ) {
        recordCall()
    }

    func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func clearTextures(
        textures: [(any MTLTexture)?],
        with commandBuffer: any MTLCommandBuffer
    ) {
        recordCall()
    }

    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        recordCall()
    }

    func duplicateTexture(
        texture: MTLTexture
    ) -> MTLTexture? {
        recordCall()
        return texture
    }

    func duplicateTexture(
        texture: MTLTexture,
        with commandBuffer: any MTLCommandBuffer
    ) -> MTLTexture? {
        recordCall()
        return texture
    }
}
