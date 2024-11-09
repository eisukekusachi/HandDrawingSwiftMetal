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

    var renderTexture: MTLTexture? {
        _renderTexture
    }

    var updateTexturePublisher: AnyPublisher<Void, Never> {
        updateTextureSubject.eraseToAnyPublisher()
    }

    private (set) var commandBuffer: MTLCommandBuffer?

    private var _renderTexture: MTLTexture? {
        didSet {
            updateTextureSubject.send(())
        }
    }

    private var textureBuffers: MTLTextureBuffers?

    private let updateTextureSubject = PassthroughSubject<Void, Never>()

    private var commandQueue: MTLCommandQueue!

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

        assert(self.device != nil, "Device is nil.")

        commandQueue = self.device!.makeCommandQueue()
        resetCommandBuffer()

        textureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: MTLTextureNodes.flippedTextureNodes,
            with: device
        )

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white

        if let device, let textureSize: CGSize = currentDrawable?.texture.size {
            _renderTexture = MTLTextureUtils.makeBlankTexture(size: textureSize, with: device)
        }
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let commandBuffer,
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

        resetCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let device else { return }

        // Align the size of `_renderTexture` with `drawableSize`
        _renderTexture = MTLTextureUtils.makeBlankTexture(size: size, with: device)
    }

}

extension CanvasView {
    func resetCommandBuffer() {
        commandBuffer = commandQueue?.makeCommandBuffer()
    }

}
