//
//  CanvasDisplayView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit
import Combine

/// A custom view for displaying textures with Metal support
class CanvasDisplayView: MTKView, MTKViewDelegate, CanvasDisplayable {

    /// Texture rendered to the screen. Its size changes when the device is rotated
    var displayTexture: MTLTexture? {
        _displayTexture
    }
    private var _displayTexture: MTLTexture? {
        didSet {
            if let textureSize = _displayTexture?.size {
                displayTextureSizeChangedSubject.send(textureSize)
            }
        }
    }

    /// Emits a `CGSize` when the size of `_displayTexture` changes
    var displayTextureSizeChanged: AnyPublisher<CGSize, Never> {
        displayTextureSizeChangedSubject.eraseToAnyPublisher()
    }
    private let displayTextureSizeChangedSubject = PassthroughSubject<CGSize, Never>()

    /// Command buffer that stores commands for rendering a single frame
    var currentFrameCommandBuffer: MTLCommandBuffer? {
        _commandBuffer
    }
    private var _commandBuffer: MTLCommandBuffer?

    /// Renderer used for drawing textures
    private let renderer: MTLRendering

    /// Buffer used to flip a texture
    private let flippedTextureBuffers: MTLTextureBuffers

    /// Queue that stores command buffers
    private let commandQueue: MTLCommandQueue

    init(frame: CGRect = .zero, renderer: MTLRendering) {
        guard
            let flippedTextureBuffer = MTLBuffers.makeTextureBuffers(
                nodes: .flippedTextureNodes,
                with: renderer.device
            ),
            let commandQueue = renderer.device.makeCommandQueue()
        else {
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = renderer
        self.flippedTextureBuffers = flippedTextureBuffer
        self.commandQueue = commandQueue
        super.init(frame: frame, device: renderer.device)
        self.delegate = self
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.isUserInteractionEnabled = false
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .white
        self.resetCommandBuffer()
    }

    required init(coder: NSCoder) {
        fatalError("Use init(frame:device:) instead.")
    }

    func draw(in view: MTKView) {
        guard
            let displayTexture,
            let currentFrameCommandBuffer,
            let drawable = view.currentDrawable
        else { return }

        // Draw `renderTexture` directly onto `drawable.texture`
        renderer.drawTexture(
            texture: displayTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: nil,
            on: drawable.texture,
            with: currentFrameCommandBuffer
        )

        currentFrameCommandBuffer.present(drawable)
        currentFrameCommandBuffer.commit()
        currentFrameCommandBuffer.waitUntilCompleted()

        resetCommandBuffer()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let device else { return }

        // Align the size of `_displayTexture` with `drawableSize`
        _displayTexture = MTLTextureCreator.makeTexture(
            width: Int(size.width),
            height: Int(size.height),
            with: device
        )
    }

    func resetCommandBuffer() {
        _commandBuffer = commandQueue.makeCommandBuffer()
    }
}
