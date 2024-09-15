//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit
import Combine

/// A custom view for displaying textures with Metal support.
final class CanvasView: MTKView, MTKViewDelegate, CanvasViewProtocol {

    /// Transformation matrix for rendering.
    var matrix: CGAffineTransform = CGAffineTransform.identity

    /// Accessor for the Metal command buffer.
    var commandBuffer: MTLCommandBuffer {
        commandBufferManager.currentCommandBuffer
    }

    var renderTexture: MTLTexture? {
        _renderTexture
    }
    var viewDrawable: (any CAMetalDrawable)? {
        currentDrawable
    }

    private var _renderTexture: MTLTexture?

    private var commandBufferManager: MTLCommandBufferManager!

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

        self.commandBufferManager = MTLCommandBufferManager(device: self.device!)

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
    }

    func initRenderTexture(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(MTLRenderer.threadGroupLength)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")

        _renderTexture = MTKTextureUtils.makeTexture(device!, textureSize)
    }

    func commitCommandsInCommandBuffer() {
        setNeedsDisplay()
    }

    func clearCommandBuffer() {
        commandBufferManager.clearCurrentCommandBuffer()
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let renderTexture,
            let drawable = view.currentDrawable
        else { return }

        // Calculate the scale to fit the source size within the destination size
        let textureToDrawableFitScale = ViewSize.getScaleToFit(renderTexture.size, to: drawable.texture.size)

        guard
            let textureBuffers = MTLBuffers.makeCanvasTextureBuffers(
                device: device,
                matrix: matrix,
                frameSize: frame.size,
                sourceSize: .init(
                    width: renderTexture.size.width * textureToDrawableFitScale,
                    height: renderTexture.size.height * textureToDrawableFitScale
                ),
                destinationSize: drawable.texture.size,
                nodes: textureNodes
            )
        else { return }

        let commandBuffer = commandBufferManager.currentCommandBuffer

        MTLRenderer.draw(
            texture: renderTexture,
            buffers: textureBuffers,
            backgroundColor: (230, 230, 230),
            on: drawable.texture,
            commandBuffer
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        commandBufferManager.clearCurrentCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setNeedsDisplay()
    }

}
