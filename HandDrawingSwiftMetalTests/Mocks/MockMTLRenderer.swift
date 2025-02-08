//
//  MockMTLRenderer.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/01/25.
//

import XCTest
import Metal
@testable import HandDrawingSwiftMetal

final class MockMTLRenderer: MTLRendering {

    var callHistory: [String] = []

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: HandDrawingSwiftMetal.MTLGrayscalePointBuffers?,
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
        texture: MTLTexture,
        buffers: HandDrawingSwiftMetal.MTLTextureBuffers,
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
                "withBackgroundColor: \(color?.rgba ?? (0, 0, 0, 0)), ",
                "on: \(destinationTextureLabel), ",
                "with: \(commandBufferLabel)",
                ")"
            ].joined()
        )
    }

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: (Int, Int, Int),
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
        withRGB rgb: (Int, Int, Int),
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
        withRGBA rgba: (Int, Int, Int, Int),
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

}
