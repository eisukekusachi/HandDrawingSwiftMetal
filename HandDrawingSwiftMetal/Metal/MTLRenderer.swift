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
        buffers: GrayscalePointBuffers?,
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
        buffers: TextureBuffers,
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

    static func drawTexture(
        texture: MTLTexture,
        on targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        copyTexture(
            sourceTexture: texture,
            destinationTexture: targetTexture,
            with: commandBuffer
        )
    }

    static func drawTextures(
        textures: [MTLTexture],
        on targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        if textures.count == 0 { return }

        for i in 0 ..< textures.count {
            if i == 0 {
                copyTexture(
                    sourceTexture: textures.first!,
                    destinationTexture: targetTexture,
                    with: commandBuffer
                )
            } else {
                mergeTextures(
                    texture: textures[i],
                    into: targetTexture,
                    with: commandBuffer
                )
            }
        }
    }

    static func makeEraseTexture(
        sourceTexture: MTLTexture,
        buffers: TextureBuffers,
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
        let w = threadGroupSize.width
        let h = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (grayscaleTexture.width  + w - 1) / w,
            height: (grayscaleTexture.height + h - 1) / h,
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

    static func merge(
        layers: [TextureLayer],
        into destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        layers.forEach {
            mergeTextures(
                texture: $0.texture,
                alpha: $0.alpha,
                into: destinationTexture,
                with: commandBuffer
            )
        }
    }
    static func mergeTextures(
        texture: MTLTexture?,
        alpha: Int = 255,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(destinationTexture.width / threadGroupLength),
            height: Int(destinationTexture.height / threadGroupLength),
            depth: 1
        )
        let w = threadGroupSize.width
        let h = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (destinationTexture.width  + w - 1) / w,
            height: (destinationTexture.height + h - 1) / h,
            depth: 1
        )
        var alpha: Float = max(0.0, min(Float(alpha) / 255.0, 1.0))

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.merge)
        encoder?.setTexture(texture, index: 0)
        encoder?.setTexture(destinationTexture, index: 1)
        encoder?.setTexture(destinationTexture, index: 2)
        encoder?.setBytes(&alpha, length: MemoryLayout<Float>.size, index: 3)
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
    static func copyTexture(
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(destinationTexture.width / threadGroupLength),
            height: Int(destinationTexture.height / threadGroupLength),
            depth: 1
        )
        let w = threadGroupSize.width
        let h = threadGroupSize.height
        let threadGroupCount = MTLSize(
            width: (destinationTexture.width  + w - 1) / w,
            height: (destinationTexture.height + h - 1) / h,
            depth: 1
        )

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(MTLPipelineManager.shared.copy)
        encoder?.setTexture(destinationTexture, index: 0)
        encoder?.setTexture(sourceTexture, index: 1)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

}
