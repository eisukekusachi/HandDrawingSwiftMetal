//
//  MTLCommandBufferExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import MetalKit
extension MTLCommandBuffer {
    @discardableResult
    func drawGrayPoints(_ pipeline: MTLRenderPipelineState?,
                        vertices: [CGPoint],
                        transparencyData: [CGFloat]? = nil,
                        diameter: Float = 2.0,
                        blurSize: Float = 1.5,
                        nAlpha: Float = 1.0,
                        on dstTexture: MTLTexture?) -> MTLCommandBuffer {
        if vertices.count == 0 { return self }
        guard   let pipeline = pipeline,
                let dstTexture = dstTexture else { return self }
        var vertexArray: [Float] = []
        var transparencyArray: [Float] = []
        var diameterPlusBlurSizeArray: [Float] = []
        for vertex in vertices {
            vertexArray.append(contentsOf: [Float(vertex.x), Float(vertex.y)])
            diameterPlusBlurSizeArray.append(blurSize * 2.0 + diameter)
        }
        if let transparencyData = transparencyData, vertices.count == transparencyData.count {
            transparencyArray.append(contentsOf: transparencyData.map { return Float($0) * nAlpha })
        } else {
            transparencyArray.append(contentsOf: [Float](repeating: 1.0, count: vertexArray.count))
        }
        let vertexBuffer = device.makeBuffer(bytes: vertexArray, length: vertexArray.count * MemoryLayout<Float>.size)
        let diameterPlusBlurSizeBuffer = device.makeBuffer(bytes: diameterPlusBlurSizeArray, length: diameterPlusBlurSizeArray.count * MemoryLayout<Float>.size)
        let transparencyBuffer = device.makeBuffer(bytes: transparencyArray, length: transparencyArray.count * MemoryLayout<Float>.size)
        var blurSize: Float = blurSize
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = dstTexture
        descriptor.colorAttachments[0].loadAction = .load
        let encoder = makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipeline)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(diameterPlusBlurSizeBuffer, offset: 0, index: 1)
        encoder?.setVertexBuffer(transparencyBuffer, offset: 0, index: 2)
        encoder?.setFragmentBytes(&blurSize, length: MemoryLayout<Float>.size, index: 0)
        encoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertexArray.count / 2)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func colorize(_ pipeline: MTLComputePipelineState?,
                  grayscaleTexture: MTLTexture?,
                  nRgb: (Float, Float, Float) = (0.0, 0.0, 0.0),
                  to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let grayscaleTexture = grayscaleTexture,
                let dstTexture = dstTexture else { return self }
        let threadgroupSize = MTLSize(width: Int(grayscaleTexture.width / 16),
                                      height: Int(grayscaleTexture.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (grayscaleTexture.width  + w - 1) / w,
            height: (grayscaleTexture.height + h - 1) / h,
            depth: 1
        )
        var rgba: [Float] = [nRgb.0, nRgb.1, nRgb.2, 1.0]
        let encoder = makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(dstTexture, index: 0)
        encoder?.setTexture(grayscaleTexture, index: 1)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func drawTexture(_ pipeline: MTLRenderPipelineState?,
                     _ srcTexture: MTLTexture?,
                     to dstTexture: MTLTexture?,
                     flipY: Bool = false) -> MTLCommandBuffer {
        let vertices: [Float] = [
            Float(-1.0), Float( 1.0), // LB
            Float( 1.0), Float( 1.0), // RB
            Float( 1.0), Float(-1.0), // RT
            Float(-1.0), Float(-1.0)  // LT
        ]
        var texCoords: [Float] = [
            0.0, 1.0, // LB
            1.0, 1.0, // RB
            1.0, 0.0, // RT
            0.0, 0.0  // LT
        ]
        if flipY {
            texCoords = [
                0.0, 0.0, // LB
                1.0, 0.0, // RB
                1.0, 1.0, // RT
                0.0, 1.0  // LT
            ]}
        let indices: [UInt16] = [
            0, 1, 2,
            0, 2, 3
        ]
        return drawTexture(pipeline, srcTexture, to: dstTexture, vertices: vertices, texCoords: texCoords, indices: indices)
    }
    @discardableResult
    func drawTexture(_ pipeline: MTLRenderPipelineState?,
                     _ srcTexture: MTLTexture?,
                     to dstTexture: MTLTexture?,
                     vertices: [Float],
                     texCoords: [Float],
                     indices: [UInt16]) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let srcTexture = srcTexture,
                let dstTexture = dstTexture,
                let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size),
                let texCoordsBuffer = device.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.size),
                let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size) else { return self }
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = dstTexture
        descriptor.colorAttachments[0].loadAction = .load
        let encoder = makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipeline)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder?.setVertexBuffer(texCoordsBuffer, offset: 0, index: 1)
        encoder?.setFragmentTexture(srcTexture, index: 0)
        encoder?.drawIndexedPrimitives(type: .triangle,
                                       indexCount: indices.count,
                                       indexType: .uint16,
                                       indexBuffer: indexBuffer,
                                       indexBufferOffset: 0)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func merge(_ pipeline: MTLComputePipelineState?, _ textures: [MTLTexture?], to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let dstTexture = dstTexture else { return self }
        for texture in textures {
            merge(pipeline, texture, to: dstTexture)
        }
        return self
    }
    @discardableResult
    func merge(_ pipeline: MTLComputePipelineState?, _ srcTexture: MTLTexture?, to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let srcTexture = srcTexture,
                let dstTexture = dstTexture else { return self }
        let threadgroupSize = MTLSize(width: Int(dstTexture.width / 16),
                                      height: Int(dstTexture.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dstTexture.width  + w - 1) / w,
            height: (dstTexture.height + h - 1) / h,
            depth: 1
        )
        let encoder = makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        encoder?.setTexture(dstTexture, index: 0)
        encoder?.setTexture(dstTexture, index: 1)
        encoder?.setTexture(srcTexture, index: 2)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func clear(_ pipeline: MTLComputePipelineState?, _ textures: [MTLTexture?]) -> MTLCommandBuffer {
        for texture in textures {
            clear(pipeline, texture)
        }
        return self
    }
    @discardableResult
    func clear(_ pipeline: MTLComputePipelineState?, _ texture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let texture = texture else { return self }
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
        let encoder = makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        encoder?.setBytes(&rgba, length: rgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func fill(_ pipeline: MTLComputePipelineState?, nRgb: (Float, Float, Float) = (0.0, 0.0, 0.0), to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        self.fill(pipeline, nRgba: (nRgb.0, nRgb.1, nRgb.2, 1.0), to: dstTexture)
        return self
    }
    @discardableResult
    func fill(_ pipeline: MTLComputePipelineState?, nRgba: (Float, Float, Float, Float) = (0.0, 0.0, 0.0, 0.0), to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let dstTexture = dstTexture else { return self }
        let threadgroupSize = MTLSize(width: Int(dstTexture.width / 16),
                                      height: Int(dstTexture.height / 16),
                                      depth: 1)
        var nRgba: [Float] = [nRgba.0, nRgba.1, nRgba.2, nRgba.3]
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dstTexture.width  + w - 1) / w,
            height: (dstTexture.height + h - 1) / h,
            depth: 1
        )
        let encoder = makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        encoder?.setBytes(&nRgba, length: nRgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(dstTexture, index: 0)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
        return self
    }
    @discardableResult
    func copy(_ pipeline: MTLComputePipelineState?, _ srcTexture: MTLTexture?, to dstTexture: MTLTexture?) -> MTLCommandBuffer {
        guard   let pipeline = pipeline,
                let srcTexture = srcTexture,
                let dstTexture = dstTexture  else { return self }
        let threadgroupSize = MTLSize(width: Int(dstTexture.width / 16),
                                      height: Int(dstTexture.height / 16),
                                      depth: 1)
        let w = threadgroupSize.width
        let h = threadgroupSize.height
        let threadgroupCount = MTLSize(
            width: (dstTexture.width  + w - 1) / w,
            height: (dstTexture.height + h - 1) / h,
            depth: 1
        )
        let encoder = makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        encoder?.setTexture(dstTexture, index: 0)
        encoder?.setTexture(srcTexture, index: 1)
        encoder?.dispatchThreadgroups(threadgroupSize, threadsPerThreadgroup: threadgroupCount)
        encoder?.endEncoding()
        return self
    }
}
