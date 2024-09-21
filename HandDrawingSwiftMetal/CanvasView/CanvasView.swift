//
//  CanvasView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit
import Combine

/// A custom view for displaying textures with Metal support.
class CanvasView: MTKView, MTKViewDelegate, CanvasViewProtocol {

    var commandBuffer: MTLCommandBuffer {
        commandManager.currentCommandBuffer
    }

    var renderTexture: MTLTexture? {
        _renderTexture
    }

    var updateTexturePublisher: AnyPublisher<Void, Never> {
        updateTextureSubject.eraseToAnyPublisher()
    }

    private var _renderTexture: MTLTexture? {
        didSet {
            updateTextureSubject.send(())
        }
    }

    private var textureBuffers: TextureBuffers?

    private let updateTextureSubject = PassthroughSubject<Void, Never>()

    private var commandManager: MTLCommandManager!

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

        commandManager = MTLCommandManager(device: self.device!)

        textureBuffers = MTLBuffers.makeTextureBuffers(device: device, nodes: flippedTextureNodes)

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white

        if let textureSize: CGSize = currentDrawable?.texture.size {
            _renderTexture = MTKTextureUtils.makeBlankTexture(device!, textureSize)
        }
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let textureBuffers,
            let renderTexture,
            let drawable = view.currentDrawable
        else { return }

        // Draw `renderTexture` directly onto `drawable.texture`
        MTLRenderer.drawTexture(
            texture: renderTexture,
            buffers: textureBuffers,
            on: drawable.texture,
            with: commandBuffer
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        commandManager.clearCurrentCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Align the size of `_renderTexture` with `drawableSize`
        _renderTexture = MTKTextureUtils.makeBlankTexture(device!, size)
    }

}

extension CanvasView {

    func clearCommandBuffer() {
        commandManager.clearCurrentCommandBuffer()
    }

    @objc private func updateDisplayLink(_ displayLink: CADisplayLink) {
        setNeedsDisplay()
    }

}
