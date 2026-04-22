//
//  File.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/04/19.
//

import CanvasView
import Foundation

@preconcurrency import MetalKit

@MainActor
struct MockRenderer: MTLRendering {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = commandQueue
    }

    var newCommandBuffer: MTLCommandBuffer? { commandQueue.makeCommandBuffer() }

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        frameSize: CGSize,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor?,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: IntRGB,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func subtractTextureWithEraseBlendMode(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {}

    func applyTexture(_ srcTexture: MTLTexture?, to dstTexture: MTLTexture?, with commandBuffer: MTLCommandBuffer) {}

    func fillColor(texture: MTLTexture, withRGB rgb: IntRGB, with commandBuffer: MTLCommandBuffer) {}

    func fillColor(texture: MTLTexture, withRGBA rgba: IntRGBA, with commandBuffer: MTLCommandBuffer) {}

    func copyTexture(srcTexture: MTLTexture, dstTexture: MTLTexture, with commandBuffer: MTLCommandBuffer) {}

    func copyTexture(srcTexture: MTLTexture, dstTexture: MTLTexture) async throws {}

    func clearTextures(textures: [MTLTexture?], with commandBuffer: MTLCommandBuffer) {}

    func clearTexture(texture: MTLTexture, with commandBuffer: MTLCommandBuffer) {}

    func makeTexture(_ textureSize: CGSize, label: String?) -> MTLTexture? {
        MockRenderer.makeTexture(size: textureSize, device: device)
    }

    func makeTexture(_ textureSize: CGSize) -> MTLTexture? {
        MockRenderer.makeTexture(size: textureSize, device: device)
    }
}

private extension MockRenderer {
    static func makeTexture(size: CGSize, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: max(Int(size.width), 1),
            height: max(Int(size.height), 1),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }
}
