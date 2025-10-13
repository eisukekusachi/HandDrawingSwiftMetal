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

    var displayTexture: MTLTexture? {
        _displayTexture
    }

    var displayTextureSizeChanged: AnyPublisher<CGSize, Never> {
        displayTextureSizeChangedSubject.eraseToAnyPublisher()
    }

    private(set) var commandBuffer: MTLCommandBuffer?

    private var renderer: MTLRendering?

    /// A texture that is rendered on the screen.
    /// Its size changes when the device is rotated.
    private var _displayTexture: MTLTexture? {
        didSet {
            if let textureSize = _displayTexture?.size {
                displayTextureSizeChangedSubject.send(textureSize)
            }
        }
    }

    private var flippedTextureBuffers: MTLTextureBuffers?

    private let displayTextureSizeChangedSubject = PassthroughSubject<CGSize, Never>()

    private var commandQueue: MTLCommandQueue!

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func initialize(renderer: MTLRendering) {
        self.renderer = renderer
    }

    private func commonInit() {
        self.device = MTLCreateSystemDefaultDevice()

        guard
            let device
        else {
            fatalError("Device is nil")
        }

        commandQueue = device.makeCommandQueue()
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
    }

    // MARK: - DrawTexture
    func draw(in view: MTKView) {
        guard
            let commandBuffer,
            let flippedTextureBuffers,
            let displayTexture,
            let drawable = view.currentDrawable
        else { return }

        // Draw `renderTexture` directly onto `drawable.texture`
        renderer?.drawTexture(
            texture: displayTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: nil,
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

        // Align the size of `_displayTexture` with `drawableSize`
        _displayTexture = MTLTextureCreator.makeTexture(
            width: Int(size.width),
            height: Int(size.height),
            with: device
        )
    }

    func resetCommandBuffer() {
        commandBuffer = commandQueue?.makeCommandBuffer()
    }
}
