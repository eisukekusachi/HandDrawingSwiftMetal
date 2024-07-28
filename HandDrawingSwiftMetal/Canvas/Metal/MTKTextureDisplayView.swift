//
//  MTKTextureDisplayView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit
import Combine

/// A custom view for displaying textures with Metal support.
class MTKTextureDisplayView: MTKView, MTKViewDelegate, MTKRenderTextureProtocol {

    /// Transformation matrix for rendering.
    var matrix: CGAffineTransform = CGAffineTransform.identity

    /// Accessor for the Metal command buffer.
    var commandBuffer: MTLCommandBuffer {
        return commandQueue.getOrCreateCommandBuffer()
    }

    var renderTexture: MTLTexture? {
        _renderTexture
    }
    var viewDrawable: (any CAMetalDrawable)? {
        currentDrawable
    }

    private var _renderTexture: MTLTexture?

    private var commandQueue: CommandQueueProtocol!

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        self.device = MTLCreateSystemDefaultDevice()
        let commandQueue = self.device!.makeCommandQueue()

        assert(self.device != nil, "Device is nil.")
        assert(commandQueue != nil, "CommandQueue is nil.")

        self.commandQueue = CommandQueue(queue: commandQueue!)

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
    }

    func initRenderTexture(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(Command.threadgroupSize)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")

        _renderTexture = MTKTextureUtils.makeTexture(device!, textureSize)
    }

    func commitCommandsInCommandBuffer() {
        setNeedsDisplay()
    }

    func clearCommandBuffer() {
        commandQueue.clearCommandBuffer()
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let renderTexture,
            let drawable = view.currentDrawable
        else { return }

        var canvasMatrix = matrix
        canvasMatrix.tx *= (CGFloat(drawable.texture.width) / frame.size.width)
        canvasMatrix.ty *= (CGFloat(drawable.texture.height) / frame.size.height)

        // Calculate the scale to fit the source size within the destination size
        let scale = ViewSize.getScaleToFit(renderTexture.size, to: drawable.texture.size)
        let resizedRenderTextureSize = CGSize(
            width: renderTexture.size.width * scale,
            height: renderTexture.size.height * scale
        )

        let textureBuffers = Buffers.makeTextureRenderingBuffers(
            device: device,
            matrix: canvasMatrix,
            sourceSize: resizedRenderTextureSize,
            destinationSize: drawable.texture.size,
            nodes: textureNodes
        )

        let commandBuffer = commandQueue.getOrCreateCommandBuffer()

        Command.draw(
            texture: _renderTexture,
            buffers: textureBuffers,
            on: drawable.texture,
            clearColor: (230, 230, 230),
            commandBuffer
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        commandQueue.clearCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setNeedsDisplay()
    }

}
