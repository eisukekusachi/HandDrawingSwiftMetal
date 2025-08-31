//
//  MTLRendering.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/31.
//

import MetalKit

@MainActor
public protocol MTLRendering {

    var device: MTLDevice? { get }

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        frameSize: CGSize,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture,
        device: MTLDevice,
        with commandBuffer: MTLCommandBuffer
    )

    func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor?,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: IntRGB,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func subtractTextureWithEraseBlendMode(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func fillTexture(
        texture: MTLTexture,
        withRGB rgb: IntRGB,
        with commandBuffer: MTLCommandBuffer
    )

    func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: IntRGBA,
        with commandBuffer: MTLCommandBuffer
    )

    func duplicateTexture(
        texture: MTLTexture?
    ) -> MTLTexture?

    func duplicateTexture(
        texture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) -> MTLTexture?

    func clearTextures(
        textures: [MTLTexture?],
        with commandBuffer: MTLCommandBuffer
    )

    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )
}
