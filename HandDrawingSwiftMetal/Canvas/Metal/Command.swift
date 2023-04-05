//
//  Command.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/31.
//

import Foundation
import MetalKit

enum Command {
    
    static let threadgroupSize: Int = 16

    static func drawCurve(onGrayscaleTexture texture: MTLTexture?,
                          buffers: PointBuffers?,
                          to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.drawGrayPoints != nil, "Call Pipeline.initalization() before here.")
        
        guard let buffers = buffers else { return }
        
        var blurSize: Float = buffers.blurSize
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .load
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(Pipeline.drawGrayPoints)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.diameterIncludingBlurBuffer, offset: 0, index: 1)
        encoder?.setVertexBuffer(buffers.alphaBuffer, offset: 0, index: 2)
        encoder?.setFragmentBytes(&blurSize, length: MemoryLayout<Float>.size, index: 0)
        encoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: buffers.numberOfPoints)
        encoder?.endEncoding()
    }
    
    static func draw(onDisplayTexture displayTexture: MTLTexture?,
                     backgroundColor: (Int, Int, Int),
                     textures: [MTLTexture?],
                     to commandBuffer: MTLCommandBuffer?) {
        
        fill(rgb: backgroundColor, dst: displayTexture, to: commandBuffer)
        
        merge(dst: displayTexture,
              textures: textures,
              to: commandBuffer)
    }
    static func draw(texture: MTLTexture?,
                     buffers: TextureBuffers?,
                     on dst: MTLTexture?,
                     clearColor color: (Int, Int, Int),
                     to commandBuffer: MTLCommandBuffer?) {
        
        guard let buffers = buffers,
              let src = texture,
              let dst = dst else {
            return
        }
        
        let clearColor = MTLClearColorMake(CGFloat(color.0) / 255.0,
                                           CGFloat(color.1) / 255.0,
                                           CGFloat(color.2) / 255.0,
                                           CGFloat(1.0))
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = dst
        descriptor.colorAttachments[0].clearColor = clearColor
        descriptor.colorAttachments[0].loadAction = .clear
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(Pipeline.drawTexture)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.texCoordsBuffer, offset: 0, index: 1)
        encoder?.setFragmentTexture(src, index: 0)
        encoder?.drawIndexedPrimitives(type: .triangle,
                                       indexCount: buffers.indicesCount,
                                       indexType: .uint16,
                                       indexBuffer: buffers.indexBuffer,
                                       indexBufferOffset: 0)
        encoder?.endEncoding()
    }
    
    static func makeEraserTexture(buffers: TextureBuffers?,
                                  currentTexture: MTLTexture?,
                                  currentDrawingTexture: MTLTexture?,
                                  result eraserTexture: MTLTexture?,
                                  to commandBuffer: MTLCommandBuffer?) {
        
        copy(src: currentTexture,
             dst: eraserTexture,
             to: commandBuffer)
        
        makeEraseTexture(buffers: buffers,
                         src: currentDrawingTexture,
                         result: eraserTexture,
                         to: commandBuffer)
    }
    
    private static func makeEraseTexture(buffers: TextureBuffers?,
                                         src: MTLTexture?,
                                         result dst: MTLTexture?,
                                         to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.erase != nil, "Call Pipeline.initalization() before here.")
        
        guard let buffers = buffers,
              let src = src,
              let dst = dst else {
            return
        }
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = dst
        descriptor.colorAttachments[0].loadAction = .load
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(Pipeline.erase)
        encoder?.setVertexBuffer(buffers.vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(buffers.texCoordsBuffer, offset: 0, index: 1)
        encoder?.setFragmentTexture(src, index: 0)
        encoder?.drawIndexedPrimitives(type: .triangle,
                                       indexCount: buffers.indicesCount,
                                       indexType: .uint16,
                                       indexBuffer: buffers.indexBuffer,
                                       indexBufferOffset: 0)
        encoder?.endEncoding()
    }
    
    static func colorize(grayscaleTexture: MTLTexture?,
                         with rgb: (Int, Int, Int),
                         result dst: MTLTexture?,
                         to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.colorize != nil, "Call Pipeline.initalization() before here.")
        
        guard let src = grayscaleTexture,
              let dst = dst else {
            return
        }
        let threadgroupSize = MTLSize(width: Int(src.width / threadgroupSize),
                                      height: Int(src.height / threadgroupSize),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (src.width  + w - 1) / w,
            height: (src.height + h - 1) / h,
            depth: 1
        )
        var rgba: [Float] = [Float(rgb.0) / 255.0,
                             Float(rgb.1) / 255.0,
                             Float(rgb.2) / 255.0,
                             1.0]
        
        let encoder = commandBuffer?.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(Pipeline.colorize)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(dst, index: 0)
        encoder?.setTexture(src, index: 1)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
    }
    
    static func fill(rgb: (Int, Int, Int), dst: MTLTexture?, to commandBuffer: MTLCommandBuffer?) {
        
        fill(rgba: (rgb.0, rgb.1, rgb.2, 255),
             dst: dst,
             to: commandBuffer)
    }
    static func fill(rgba: (Int, Int, Int, Int),
                     dst: MTLTexture?,
                     to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.fillColor != nil, "Call Pipeline.initalization() before here.")
        
        guard let dst = dst else {
            return
        }

        let threadgroupSize = MTLSize(width: Int(dst.width / 16),
                                      height: Int(dst.height / 16),
                                      depth: 1)
        var nRgba: [Float] = [Float(rgba.0) / 255.0,
                              Float(rgba.1) / 255.0,
                              Float(rgba.2) / 255.0,
                              Float(rgba.3) / 255.0]
        
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dst.width  + w - 1) / w,
            height: (dst.height + h - 1) / h,
            depth: 1
        )
        
        let encoder = commandBuffer?.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(Pipeline.fillColor)
        encoder?.setBytes(&nRgba, length: nRgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(dst, index: 0)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
    }
    
    
    static func merge(dst: MTLTexture?, textures: [MTLTexture?], to commandBuffer: MTLCommandBuffer?) {
        
        textures.forEach {
            merge(dst: dst, texture: $0, to: commandBuffer)
        }
    }
    static func merge(dst: MTLTexture?, texture: MTLTexture?, to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.merge != nil, "Call Pipeline.initalization() before here.")
        
        guard let src = texture,
              let dst = dst else {
            return
        }
        
        let threadgroupSize = MTLSize(width: Int(dst.width / 16),
                                      height: Int(dst.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dst.width  + w - 1) / w,
            height: (dst.height + h - 1) / h,
            depth: 1
        )
        
        let encoder = commandBuffer?.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(Pipeline.merge)
        encoder?.setTexture(dst, index: 0)
        encoder?.setTexture(dst, index: 1)
        encoder?.setTexture(src, index: 2)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
    }
    
    static func clear(textures: [MTLTexture?], to commandBuffer: MTLCommandBuffer?) {
        
        textures.forEach {
            clear(texture: $0, to: commandBuffer)
        }
    }
    static func clear(texture: MTLTexture?, to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.fillColor != nil, "Call Pipeline.initalization() before here.")
        
        guard let texture = texture else {
            return
        }
        let threadgroupSize = MTLSize(width: Int(texture.width / 16),
                                      height: Int(texture.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (texture.width  + w - 1) / w,
            height: (texture.height + h - 1) / h,
            depth: 1
        )
        var rgba: [Float] = [0.0, 0.0, 0.0, 0.0]
        
        let encoder = commandBuffer?.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(Pipeline.fillColor)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
    }
    static func copy(src: MTLTexture?, dst: MTLTexture?, to commandBuffer: MTLCommandBuffer?) {
        
        assert(Pipeline.copy != nil, "Call Pipeline.initalization() before here.")
        
        guard let src = src,
              let dst = dst else { return }
        let threadgroupSize = MTLSize(width: Int(dst.width / 16),
                                      height: Int(dst.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dst.width  + w - 1) / w,
            height: (dst.height + h - 1) / h,
            depth: 1
        )
        
        let encoder = commandBuffer?.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(Pipeline.copy)
        encoder?.setTexture(dst, index: 0)
        encoder?.setTexture(src, index: 1)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
    }
}
