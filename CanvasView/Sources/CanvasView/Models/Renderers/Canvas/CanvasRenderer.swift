//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
@preconcurrency import MetalKit

/// Draws textures on `canvasTexture` and displays it on the screen
@MainActor public final class CanvasRenderer: ObservableObject {

    /// Command buffer for a single frame
    public var currentFrameCommandBuffer: MTLCommandBuffer? {
        displayView.currentFrameCommandBuffer
    }

    /// Size of the texture rendered on the screen
    public var displayTextureSize: CGSize? {
        displayView.displayTexture?.size
    }

    private var frameSize: CGSize = .zero

    private let renderer: MTLRendering

    /// Buffers used to draw textures with vertical flipping
    private let flippedTextureBuffers: MTLTextureBuffers

    /// Background color of the canvas
    private var backgroundColor: UIColor = .white

    /// Base background color of the canvas. this color that appears when the canvas is rotated or moved
    private var baseBackgroundColor: UIColor = .lightGray

    /// View for displaying content on the screen
    private let displayView: CanvasDisplayable

    private var cancellables = Set<AnyCancellable>()

    public init(
        device: MTLDevice,
        displayView: CanvasDisplayable
    ) {
        guard let buffer = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        ) else {
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = MTLRenderer(device: device)
        self.displayView = displayView
        self.flippedTextureBuffers = buffer
    }

    public func setup(
        backgroundColor: UIColor?,
        baseBackgroundColor: UIColor?
    ) {
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let baseBackgroundColor { self.baseBackgroundColor = baseBackgroundColor }
    }

    public func setFrameSize(_ size: CGSize) {
        self.frameSize = size
    }

    public func resetCommandBuffer() {
        displayView.resetCommandBuffer()
    }
}

extension CanvasRenderer {

    /// Updates `canvasTexture` using `currentTexture` and the background color
    public func updateCanvasTexture(
        currentTexture: MTLTexture?,
        canvasTexture: MTLTexture?
    ) {
        guard
            let canvasTexture,
            let currentTexture,
            let currentFrameCommandBuffer
        else { return }

        renderer.fillColor(
            texture: canvasTexture,
            withRGB: backgroundColor.rgb,
            with: currentFrameCommandBuffer
        )

        renderer.mergeTexture(
            texture: currentTexture,
            alpha: 255,
            into: canvasTexture,
            with: currentFrameCommandBuffer
        )
    }

    /// Applies `realtimeDrawingTexture` to `currentTexture`, then clears `realtimeDrawingTexture`
    func applyRealtimeDrawingTexture(
        _ realtimeDrawingTexture: MTLTexture?,
        to currentTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        renderer.applyTexture(
            realtimeDrawingTexture,
            to: currentTexture,
            with: commandBuffer
        )
    }

    /// Draws `canvasTexture` to the display, applying the current transform and requests a screen update
    public func drawCanvasTextureToDisplay(
        matrix: CGAffineTransform,
        canvasTexture: MTLTexture?
    ) {
        guard
            let currentFrameCommandBuffer,
            let canvasTexture,
            let displayTexture = displayView.displayTexture
        else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: baseBackgroundColor,
            on: displayTexture,
            with: currentFrameCommandBuffer
        )

        displayView.setNeedsDisplay()
    }
}

extension CanvasRenderer {
    func makeTexture(
        _ textureSize: CGSize,
        label: String
    ) -> MTLTexture? {
        renderer.makeTexture(
            textureSize,
            label: label
        )
    }
}
