//
//  TextureDisplayView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit

/// A custom view for displaying textures with Metal support.
class TextureDisplayView: MTKView, MTKViewDelegate {

    /// The size of the texture to be displayed.
    var textureSize: CGSize!

    /// Transformation matrix for rendering.
    var matrix: CGAffineTransform = CGAffineTransform.identity

    /// Accessor for the Metal command buffer.
    var commandBuffer: MTLCommandBuffer {
        return commandQueue.getOrCreateCommandBuffer()
    }

    /// Accessor for the output image rendered on this view.
    var outputImage: UIImage? {
        if let texture = displayTexture,
           let data = UIImage.makeCFData(texture, flipY: true),
           let image = UIImage.makeImage(cfData: data, width: texture.width, height: texture.height) {
            return image
        } else {
            return nil
        }
    }

    private(set) var displayTexture: MTLTexture!
    private(set) var displayLink: CADisplayLink?

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

        // Configure the display link for rendering.
        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink(_:)))
        displayLink?.add(to: .current, forMode: .common)
        displayLink?.isPaused = true

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
    }

    func initializeTextures(textureSize: CGSize) {
        let minSize: CGFloat = CGFloat(Command.threadgroupSize)
        assert(textureSize.width >= minSize && textureSize.height >= minSize, "The textureSize is not appropriate")

        self.textureSize = textureSize

        self.displayTexture = device!.makeTexture(textureSize)
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }

        var canvasMatrix = matrix
        canvasMatrix.tx *= (CGFloat(drawable.texture.width) / frame.size.width)
        canvasMatrix.ty *= (CGFloat(drawable.texture.height) / frame.size.height)

        let textureBuffers = Buffers.makeTextureBuffers(device: device!,
                                                        textureSize: displayTexture.size,
                                                        drawableSize: drawable.texture.size,
                                                        matrix: canvasMatrix,
                                                        nodes: textureNodes)

        let commandBuffer = commandQueue.getOrCreateCommandBuffer()

        Command.draw(texture: displayTexture,
                     buffers: textureBuffers,
                     on: drawable.texture,
                     clearColor: (230, 230, 230),
                     commandBuffer)

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        commandQueue.disposeCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// Start or stop the display link loop based on the 'play' parameter.
    func runDisplayLinkLoop(_ play: Bool) {
        if play {
            if displayLink?.isPaused == true {
                displayLink?.isPaused = false
            }
        } else {
            if displayLink?.isPaused == false {
                // Pause the display link after updating the display.
                setNeedsDisplay()
                displayLink?.isPaused = true
            }
        }
    }

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        setNeedsDisplay()
    }
}
