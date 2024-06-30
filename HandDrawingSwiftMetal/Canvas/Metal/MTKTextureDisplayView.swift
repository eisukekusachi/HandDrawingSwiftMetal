//
//  MTKTextureDisplayView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit

protocol MTKRenderTextureProtocol {
    var commandBuffer: MTLCommandBuffer { get }

    var renderTexture: MTLTexture? { get }
    var viewDrawable: CAMetalDrawable? { get }

    func setNeedsDisplay()
}

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

    func initRootTexture(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(Command.threadgroupSize)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")

        _renderTexture = MTKTextureUtils.makeTexture(device!, textureSize)
    }

    func commitCommandsInCommandBuffer() {
        setNeedsDisplay()
    }

    func setCommandBufferToNil() {
        commandQueue.setCommandBufferToNil()
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

        let textureBuffers = Buffers.makeTextureBuffers(device: device!,
                                                        textureSize: renderTexture.size,
                                                        drawableSize: drawable.texture.size,
                                                        matrix: canvasMatrix,
                                                        nodes: textureNodes)

        let commandBuffer = commandQueue.getOrCreateCommandBuffer()

        Command.draw(texture: _renderTexture,
                     buffers: textureBuffers,
                     on: drawable.texture,
                     clearColor: (230, 230, 230),
                     commandBuffer)

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        commandQueue.setCommandBufferToNil()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
}
