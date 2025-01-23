//
//  MTLRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import MetalKit

protocol MTLRendering {

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture,
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
        color rgb: (Int, Int, Int),
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func mergeTextureWithEraseBlendMode(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func mergeTexture(
        texture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

    func fillTexture(
        texture: MTLTexture,
        withRGB rgb: (Int, Int, Int),
        with commandBuffer: MTLCommandBuffer
    )

    func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: (Int, Int, Int, Int),
        with commandBuffer: MTLCommandBuffer
    )

    func clearTextures(
        textures: [MTLTexture?],
        with commandBuffer: MTLCommandBuffer
    )

    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    )

}

final class MTLRenderer: MTLRendering {

    static let shared = MTLRenderer()

    static let threadGroupLength: Int = 16

    private let pipelines = MTLPipelines()

    func drawGrayPointBuffersWithMaxBlendMode(
        buffers: MTLGrayscalePointBuffers?,
        onGrayscaleTexture texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let buffers else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .load

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipelines.drawGrayPointsWithMaxBlendMode)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.diameterIncludingBlurBuffer, offset: 0, index: 1)
        encoder?.setVertexBuffer(buffers.brightnessBuffer, offset: 0, index: 2)
        encoder?.setVertexBuffer(buffers.blurSizeBuffer, offset: 0, index: 3)
        encoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: buffers.numberOfPoints)
        encoder?.endEncoding()
    }

    func drawTexture(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        withBackgroundColor color: UIColor? = nil,
        on destinationTexture: MTLTexture,
        with commandBuffer: (any MTLCommandBuffer)
    ) {
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
        encoder?.setRenderPipelineState(pipelines.drawTexture)
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

    func mergeTextureWithEraseBlendMode(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = destinationTexture
        descriptor.colorAttachments[0].loadAction = .load

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipelines.eraseTexture)
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

    func mergeTexture(
        texture: MTLTexture,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        mergeTexture(
            texture: texture,
            alpha: 255,
            on: destinationTexture,
            with: commandBuffer
        )
    }

    func mergeTexture(
        texture: MTLTexture,
        alpha: Int = 255,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            texture.size == destinationTexture.size
        else {
            Logger.standard.error("Texture size mismatch")
            return
        }

        let threadGroupSize = MTLSize(
            width: Int(destinationTexture.width / MTLRenderer.threadGroupLength),
            height: Int(destinationTexture.height / MTLRenderer.threadGroupLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (destinationTexture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (destinationTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var alpha: Float = max(0.0, min(Float(alpha) / 255.0, 1.0))

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipelines.mergeTextures)
        encoder?.setTexture(texture, index: 0)
        encoder?.setTexture(destinationTexture, index: 1)
        encoder?.setTexture(destinationTexture, index: 2)
        encoder?.setBytes(&alpha, length: MemoryLayout<Float>.size, index: 3)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: (Int, Int, Int),
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(grayscaleTexture.width / MTLRenderer.threadGroupLength),
            height: Int(grayscaleTexture.height / MTLRenderer.threadGroupLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (grayscaleTexture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (grayscaleTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var rgba: [Float] = [
            Float(rgb.0) / 255.0,
            Float(rgb.1) / 255.0,
            Float(rgb.2) / 255.0,
            1.0
        ]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipelines.colorize)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(grayscaleTexture, index: 0)
        encoder?.setTexture(destinationTexture, index: 1)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    func fillTexture(
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

    func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: (Int, Int, Int, Int),
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(texture.width / MTLRenderer.threadGroupLength),
            height: Int(texture.height / MTLRenderer.threadGroupLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (texture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var nRgba: [Float] = [
            Float(rgba.0) / 255.0,
            Float(rgba.1) / 255.0,
            Float(rgba.2) / 255.0,
            Float(rgba.3) / 255.0
        ]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipelines.fillColor)
        encoder?.setBytes(&nRgba, length: nRgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    func clearTextures(
        textures: [MTLTexture?],
        with commandBuffer: MTLCommandBuffer
    ) {
        textures.forEach {
            if let texture = $0 {
                clearTexture(
                    texture: texture,
                    with: commandBuffer
                )
            }
        }
    }
    func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        precondition(
            texture.width >= MTLRenderer.threadGroupLength &&
            texture.height >= MTLRenderer.threadGroupLength
        )

        let threadGroupSize = MTLSize(
            width: Int(texture.width / MTLRenderer.threadGroupLength),
            height: Int(texture.height / MTLRenderer.threadGroupLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (texture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var rgba: [Float] = [0.0, 0.0, 0.0, 0.0]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipelines.fillColor)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

}
