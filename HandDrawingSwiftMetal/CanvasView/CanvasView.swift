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

    private var flippedTextureBuffers: MTLTextureBuffers?

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

        flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white

        if let device, let textureSize: CGSize = currentDrawable?.texture.size {
            _renderTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        }
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let commandBuffer,
            let flippedTextureBuffers,
            let renderTexture,
            let drawable = view.currentDrawable
        else { return }

        // Draw `renderTexture` directly onto `drawable.texture`
        MTLRenderer.drawTexture(
            texture: renderTexture,
            buffers: flippedTextureBuffers,
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
        _renderTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
    }

}

extension CanvasView {
    func resetCommandBuffer() {
        commandBuffer = commandQueue?.makeCommandBuffer()
    }

}
