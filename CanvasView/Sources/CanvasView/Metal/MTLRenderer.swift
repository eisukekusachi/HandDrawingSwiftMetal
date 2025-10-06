//
//  MTLRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

@preconcurrency import MetalKit

let canvasMinimumTextureLength: Int = 16

@MainActor
public final class MTLRenderer: Sendable, MTLRendering {

    public var device: MTLDevice {
        _device
    }
    private var _device: MTLDevice

    public var newCommandBuffer: MTLCommandBuffer? {
        commandQueue?.makeCommandBuffer()
    }

    private let commandQueue: MTLCommandQueue?

    private let pipelines: MTLPipelines

    init(device: MTLDevice) {
        self._device = device
        self.pipelines = MTLPipelines(device: device)
        self.commandQueue = device.makeCommandQueue()
    }

    public func drawGrayPointBuffersWithMaxBlendMode(
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

    public func drawTexture(
        texture: MTLTexture?,
        matrix: CGAffineTransform,
        frameSize: CGSize,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture,
        device: MTLDevice,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let textureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                matrix: matrix,
                frameSize: frameSize,
                sourceSize: .init(
                    width: texture.size.width * ViewSize.getScaleToFit(texture.size, to: destinationTexture.size),
                    height: texture.size.height * ViewSize.getScaleToFit(texture.size, to: destinationTexture.size)
                ),
                destinationSize: destinationTexture.size,
                with: device
            )
        else {
            Logger.error(String(localized: "Unable to load required data", bundle: .module))
            return
        }

        drawTexture(
            texture: texture,
            buffers: textureBuffers,
            withBackgroundColor: backgroundColor,
            on: destinationTexture,
            with: commandBuffer
        )
    }

    public func drawTexture(
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
                min(CGFloat(rgba.r) / 255.0, 1.0),
                min(CGFloat(rgba.g) / 255.0, 1.0),
                min(CGFloat(rgba.b) / 255.0, 1.0),
                min(CGFloat(rgba.a) / 255.0, 1.0)
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

    public func drawTexture(
        grayscaleTexture: MTLTexture,
        color rgb: IntRGB,
        on destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(grayscaleTexture.width / canvasMinimumTextureLength),
            height: Int(grayscaleTexture.height / canvasMinimumTextureLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (grayscaleTexture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (grayscaleTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var rgba: [Float] = [
            Float(rgb.r) / 255.0,
            Float(rgb.g) / 255.0,
            Float(rgb.b) / 255.0,
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

    public func subtractTextureWithEraseBlendMode(
        texture: MTLTexture,
        buffers: MTLTextureBuffers,
        from destinationTexture: MTLTexture,
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

    public func mergeTexture(
        texture: MTLTexture,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        mergeTexture(
            texture: texture,
            alpha: 255,
            into: destinationTexture,
            with: commandBuffer
        )
    }

    public func mergeTexture(
        texture: MTLTexture,
        alpha: Int = 255,
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            texture.size == destinationTexture.size
        else {
            Logger.error(String(localized: "Texture size mismatch", bundle: .module))
            return
        }

        let threadGroupSize = MTLSize(
            width: Int(destinationTexture.width / canvasMinimumTextureLength),
            height: Int(destinationTexture.height / canvasMinimumTextureLength),
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

    public func fillTexture(
        texture: MTLTexture,
        withRGB rgb: IntRGB,
        with commandBuffer: MTLCommandBuffer
    ) {
        fillTexture(
            texture: texture,
            withRGBA: .init(rgb.r, rgb.g, rgb.b, 255),
            with: commandBuffer
        )
    }

    public func fillTexture(
        texture: MTLTexture,
        withRGBA rgba: IntRGBA,
        with commandBuffer: MTLCommandBuffer
    ) {
        let threadGroupSize = MTLSize(
            width: Int(texture.width / canvasMinimumTextureLength),
            height: Int(texture.height / canvasMinimumTextureLength),
            depth: 1
        )
        let threadGroupCount = MTLSize(
            width: (texture.width  + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        var nRgba: [Float] = [
            Float(rgba.r) / 255.0,
            Float(rgba.g) / 255.0,
            Float(rgba.b) / 255.0,
            Float(rgba.a) / 255.0
        ]

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipelines.fillColor)
        encoder?.setBytes(&nRgba, length: nRgba.count * MemoryLayout<Float>.size, index: 0)
        encoder?.setTexture(texture, index: 0)
        encoder?.dispatchThreadgroups(threadGroupSize, threadsPerThreadgroup: threadGroupCount)
        encoder?.endEncoding()
    }

    public func clearTextures(
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
    public func clearTexture(
        texture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        precondition(
            texture.width >= canvasMinimumTextureLength &&
            texture.height >= canvasMinimumTextureLength
        )

        let threadGroupSize = MTLSize(
            width: Int(texture.width / canvasMinimumTextureLength),
            height: Int(texture.height / canvasMinimumTextureLength),
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

    public func duplicateTexture(
        texture: MTLTexture?
    ) async -> MTLTexture? {
        guard
            let texture,
            let commandBuffer = commandQueue?.makeCommandBuffer(),
            let resultTexture = MTLTextureCreator.makeTexture(
                label: texture.label,
                width: texture.width,
                height: texture.height,
                with: device
            )
        else { return nil }

        guard
            texture.pixelFormat == resultTexture.pixelFormat && texture.sampleCount == resultTexture.sampleCount
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(localized: "Invalid value", bundle: .module)
            )
            Logger.error(error)
            return nil
        }

        await copyTexture(
            srctexture: texture,
            dstTexture: resultTexture,
            commandBuffer: commandBuffer
        )

        return await withCheckedContinuation { (continuation: CheckedContinuation<MTLTexture?, Never>) in
            commandBuffer.addCompletedHandler { @Sendable buffer in
                switch buffer.status {
                case .completed:
                    continuation.resume(returning: resultTexture)
                case .error:
                    if let e = buffer.error { Logger.error(e) }
                    continuation.resume(returning: nil)
                default:
                    continuation.resume(returning: nil)
                }
            }
            commandBuffer.commit()
        }
    }

    public func copyTexture(
        srctexture: MTLTexture?,
        dstTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer
    ) async {
        guard
            let srctexture,
            let dstTexture,
            let encoder = commandBuffer.makeBlitCommandEncoder(),
            srctexture.pixelFormat == dstTexture.pixelFormat && srctexture.sampleCount == dstTexture.sampleCount
        else { return }

        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: srctexture.width, height: srctexture.height, depth: 1)

        encoder.copy(
            from: srctexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: dstTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin
        )
        encoder.endEncoding()
    }
}
