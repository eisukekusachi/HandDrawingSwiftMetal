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

    let device: MTLDevice

    init() {
        device = MTLCreateSystemDefaultDevice()!
    }

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawGrayPointBuffersWithMaxBlendMode(",
                "buffers: buffers, ",
                "onGrayscaleTexture: \(textureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        frameSize: CGSize,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture,
        device: MTLDevice,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture?.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawTexture(",
                "texture: \(textureLabel), ",
                "frameSize: \(frameSize.width), \(frameSize.height)",
                "withBackgroundColor: \(backgroundColor.rgba), ",
                "on: \(destinationTextureLabel) ",
                "device: \(device.name), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor?,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawTexture(",
                "texture: \(textureLabel), ",
                "buffers: buffers, ",
                "withBackgroundColor: \(color?.rgba.tuple ?? (0, 0, 0, 0)), ",
                "on: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: IntRGB,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let grayscaleTextureLabel = grayscaleTexture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "drawTexture(",
                "grayscaleTexture: \(grayscaleTextureLabel), ",
                "color: \(rgb), ",
                "on: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func subtractTextureWithEraseBlendMode(
        texture: any MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: any MTLTexture,
        with commandBuffer: any MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "subtractTextureWithEraseBlendMode(",
                "texture: \(sourceTexture), ",
                "buffers: buffers, ",
                "from: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func fillTexture(
        texture: MTLTexture,
        withRGB rgb: IntRGB,
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "fillTexture(",
                "texture: \(textureLabel), ",
                "withRGB: \(rgb), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: IntRGBA,
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "fillTexture(",
                "texture: \(textureLabel), ",
                "withRGBA: \(rgba), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "mergeTexture(",
                "texture: \(sourceTexture), ",
                "into: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let sourceTexture = texture.label ?? ""
        let destinationTextureLabel = destinationTexture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "mergeTexture(",
                "texture: \(sourceTexture), ",
                "alpha: \(alpha), ",
                "into: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func clearTextures(
        textures: [(any MTLTexture)?],
        with commandBuffer: any MTLCommandBuffer
    ) {
        let textureLabels = textures.compactMap { $0?.label }.joined(separator: ", ")
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "clearTextures(",
                "textures: [\(textureLabels)], ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let textureLabel = texture.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "clearTexture(",
                "texture: \(textureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func duplicateTexture(
        texture: MTLTexture?
    ) -> MTLTexture? {
        let textureLabel = texture?.label ?? ""

        callHistory.append(
            [
                "duplicateTexture(",
                "texture: \(textureLabel)",
                ")"
            ].joined()
        )
        return texture
    }

    func duplicateTexture(
        texture: MTLTexture?,
        with commandBuffer: any MTLCommandBuffer
    ) -> MTLTexture? {
        let textureLabel = texture?.label ?? ""
        let commandBufferLabel = commandBuffer.label ?? ""
        callHistory.append(
            [
                "clearTexture(",
                "texture: \(textureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
        return texture
    }
}
