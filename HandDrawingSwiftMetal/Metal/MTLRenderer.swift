//
//  MTLRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import MetalKit

enum MTLRenderer {
    static let threadGroupLength: Int = 16

    static func drawCurve(
        buffers: MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer?
    ) {
        guard let buffers = buffers else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .load

        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(MTLPipelineManager.shared.drawPointsWithMaxBlendMode)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.diameterIncludingBlurBuffer, offset: 0, index: 1)
        encoder?.setVertexBuffer(buffers.brightnessBuffer, offset: 0, index: 2)
        encoder?.setVertexBuffer(buffers.blurSizeBuffer, offset: 0, index: 3)
        encoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: buffers.numberOfPoints)
        encoder?.endEncoding()
    }

    static func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor? = nil,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let destinationTexture else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = destinationTexture
        descriptor.colorAttachments[0].loadAction = .load

        if let rgba = color?.rgba {
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(
                min(CGFloat(rgba.0) / 255.0, 1.0),
                min(CGFloat(rgba.1) / 255.0, 1.0),
                min(CGFloat(rgba.2) / 255.0, 1.0),
                min(CGFloat(rgba.3) / 255.0, 1.0)
            )
        }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(MTLPipelineManager.shared.drawTexture)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.texCoordsBuffer, offset: 0, index: 1)
        encoder?.setFragmentTexture(texture, index: 0)
        encoder?.drawIndexedPrimitives(
            type: .triangle,
            indexCount: buffers.indicesCount,
            indexType: .uint16,
            indexBuffer: buffers.indexBuffer,
            indexBufferOffset: 0
        )
        encoder?.endEncoding()
    }

    static func makeEraseTexture(
        sourceTexture: MTLTexture,
        buffers: MTLTextureBuffers,
        into targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = targetTexture
        descriptor.colorAttachments[0].loadAction = .load

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(MTLPipelineManager.shared.erase)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.texCoordsBuffer, offset: 0, index: 1)
        encoder?.setFragmentTexture(sourceTexture, index: 0)
        encoder?.drawIndexedPrimitives(
            type: .triangle,
            indexCount: buffers.indicesCount,
            indexType: .uint16,
            indexBuffer: buffers.indexBuffer,
            indexBufferOffset: 0
        )
        encoder?.endEncoding()
    }

    static func colorizeTexture(
        grayscaleTexture: MTLTexture,
        color rgb: (Int, Int, Int),
        resultTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(grayscaleTexture.width / threadGroupLength),
            height: Int(grayscaleTexture.height / threadGroupLength),
            depth: 1
        )
        let width = threadGroupSize.width
        let height = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (grayscaleTexture.width  + width - 1) / width,
            height: (grayscaleTexture.height + height - 1) / height,
            depth: 1
        )
        var rgba: [Float] = [
            Float(rgb.0) / 255.0,
            Float(rgb.1) / 255.0,
            Float(rgb.2) / 255.0,
            1.0
        ]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.colorize)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(grayscaleTexture, index: 0)
        encoder?.setTexture(resultTexture, index: 1)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    static func fillTexture(
        texture: MTLTexture,
        withRGB rgb: (Int, Int, Int),
        with commandBuffer: MTLCommandBuffer
    ) {
        fillTexture(
            texture: texture,
            withRGBA: (rgb.0, rgb.1, rgb.2, 255),
            with: commandBuffer
        )
    }
    static func fillTexture(
        texture: MTLTexture?,
        withRGBA rgba: (Int, Int, Int, Int),
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let texture else { return }

        let threadGroupSize = MTLSize(
            width: Int(texture.width / threadGroupLength),
            height: Int(texture.height / threadGroupLength),
            depth: 1
        )
        var nRgba: [Float] = [
            Float(rgba.0) / 255.0,
            Float(rgba.1) / 255.0,
            Float(rgba.2) / 255.0,
            Float(rgba.3) / 255.0
        ]

        let width = threadGroupSize.width
        let height = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (texture.width  + width - 1) / width,
            height: (texture.height + height - 1) / height,
            depth: 1
        )

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.fillColor)
        encoder?.setBytes(&nRgba, length: nRgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    static func mergeTextures(
        sourceTexture: MTLTexture?,
        sourceAlpha: Int = 255,
        destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let textureSize = sourceTexture?.size, textureSize == destinationTexture.size
        else { return }

        let threadGroupSize = MTLSize(
            width: Int(destinationTexture.width / threadGroupLength),
            height: Int(destinationTexture.height / threadGroupLength),
            depth: 1
        )
        let width = threadGroupSize.width
        let height = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (destinationTexture.width  + width - 1) / width,
            height: (destinationTexture.height + height - 1) / height,
            depth: 1
        )
        var sourceAlpha: Float = max(0.0, min(Float(sourceAlpha) / 255.0, 1.0))

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.mergeTextures)
        encoder?.setTexture(sourceTexture, index: 0)
        encoder?.setTexture(destinationTexture, index: 1)
        encoder?.setTexture(destinationTexture, index: 2)
        encoder?.setBytes(&sourceAlpha, length: MemoryLayout<Float>.size, index: 3)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    static func clearTextures(
        textures: [MTLTexture?],
        with commandBuffer: MTLCommandBuffer
    ) {
        textures.forEach {
            clearTexture(
                texture: $0,
                with: commandBuffer
            )
        }
    }
    static func clearTexture(
        texture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let texture else { return }

        let threadGroupSize = MTLSize(
            width: Int(texture.width / threadGroupLength),
            height: Int(texture.height / threadGroupLength),
            depth: 1
        )
        let width = threadGroupSize.width
        let height = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (texture.width  + width - 1) / width,
            height: (texture.height + height - 1) / height,
            depth: 1
        )
        var rgba: [Float] = [0.0, 0.0, 0.0, 0.0]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.fillColor)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

}
