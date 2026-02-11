//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
@preconcurrency import MetalKit

/// Renders textures for display by loading and merging layer textures from `TextureLayersDocumentsRepository`
@MainActor public final class CanvasRenderer: ObservableObject {

    /// Command buffer for a single frame
    public var currentFrameCommandBuffer: MTLCommandBuffer? {
        displayView.currentFrameCommandBuffer
    }

    /// Size of the canvas texture
    public var textureSize: CGSize? {
        canvasTexture?.size
    }

    /// Size of the texture rendered on the screen
    public var displayTextureSize: CGSize? {
        displayView.displayTexture?.size
    }

    /// Texture that combines the background color and the textures of `currentTexture`
    private(set) var canvasTexture: MTLTexture?

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    private var frameSize: CGSize = .zero

    private var matrix: CGAffineTransform = .identity

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
        renderer: MTLRendering,
        displayView: CanvasDisplayable
    ) {
        guard let buffer = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        ) else {
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = renderer
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

    public func setupTextures(textureSize: CGSize) throws {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)",
                    bundle: .module
                )
            )
            Logger.error(error)
            throw error
        }

        guard
            let canvasTexture = makeTexture(textureSize, label: "canvasTexture"),
            let realtimeDrawingTexture = makeTexture(textureSize, label: "realtimeDrawingTexture")
        else {
            let error = NSError(
                title: String(localized: "Error", bundle: .module),
                message: String(
                    localized: "Failed to create new texture",
                    bundle: .module
                )
            )
            Logger.error(error)
            throw error
        }
        self.canvasTexture = canvasTexture
        self.realtimeDrawingTexture = realtimeDrawingTexture
    }

    public func setFrameSize(_ size: CGSize) {
        self.frameSize = size
    }

    public func setMatrix(_ matrix: CGAffineTransform) {
        self.matrix = matrix
    }

    public func resetCommandBuffer() {
        displayView.resetCommandBuffer()
    }
}

extension CanvasRenderer {

    /// Refreshes the entire screen using textures
    public func refreshCanvas(
        currentTexture: MTLTexture?,
        useRealtimeDrawingTexture: Bool
    ) {
        guard
            let canvasTexture,
            let currentTexture,
            let realtimeDrawingTexture,
            let currentFrameCommandBuffer
        else { return }

        renderer.fillColor(
            texture: canvasTexture,
            withRGB: backgroundColor.rgb,
            with: currentFrameCommandBuffer
        )

        renderer.mergeTexture(
            texture: useRealtimeDrawingTexture ? realtimeDrawingTexture : currentTexture,
            alpha: 255,
            into: canvasTexture,
            with: currentFrameCommandBuffer
        )

        drawCanvasToDisplay()
    }

    /// Draws `canvasTexture` to the display, applying the current transform and requests a screen update
    public func drawCanvasToDisplay() {
        guard
            let displayTexture = displayView.displayTexture,
            let currentFrameCommandBuffer
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

    /// Draws the given texture onto `selectedLayerTexture`
    func drawSelectedLayerTexture(
        currentTexture: MTLTexture?,
        from texture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let currentTexture
        else { return }

        renderer.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: currentTexture,
            with: commandBuffer
        )
    }
}

extension CanvasRenderer {
    func makeTexture(
        _ textureSize: CGSize,
        label: String
    ) -> MTLTexture? {
        let texture = MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
        texture?.label = label
        return texture
    }
}
