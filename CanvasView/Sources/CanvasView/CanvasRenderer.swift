//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
@preconcurrency import MetalKit

/// A class that renders textures from `TextureRepository` onto the texture of `displayView`
@MainActor
public final class CanvasRenderer: ObservableObject {

    public var device: MTLDevice? {
        renderer?.device
    }

    public var frameSize: CGSize = .zero

    public var matrix: CGAffineTransform = .identity

    private(set) var renderer: MTLRendering?

    /// The background color of the canvas
    private var backgroundColor: UIColor = .white

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    private var baseBackgroundColor: UIColor = .lightGray

    private var displayView: CanvasDisplayable?

    private var flippedTextureBuffers: MTLTextureBuffers?

    /// The texture of the selected layer
    private(set) var selectedLayerTexture: MTLTexture!

    /// The texture that combines the background color and the textures of `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`
    private(set) var canvasTexture: MTLTexture?

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture!

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture!

    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public func initialize(
        displayView: CanvasDisplayable,
        renderer: MTLRendering,
        environmentConfiguration: EnvironmentConfiguration
    ) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        )

        self.displayView = displayView

        self.backgroundColor = environmentConfiguration.backgroundColor
        self.baseBackgroundColor = environmentConfiguration.baseBackgroundColor
    }

    public func initializeTextures(textureSize: CGSize) {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            assert(false, "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return
        }

        guard
            let device = renderer?.device,
            let unselectedBottomTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let selectedLayerTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let unselectedTopTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let canvasTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.unselectedBottomTexture = unselectedBottomTexture
        self.selectedLayerTexture = selectedLayerTexture
        self.unselectedTopTexture = unselectedTopTexture
        self.canvasTexture = canvasTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.selectedLayerTexture?.label = "selectedLayerTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"
        self.canvasTexture?.label = "canvasTexture"
    }
}

extension CanvasRenderer {
    public var drawableSize: CGSize? {
        displayView?.displayTexture?.size
    }

    public func resetCommandBuffer() {
        displayView?.resetCommandBuffer()
    }

    public func copyTexture(
        srcTexture: MTLTexture,
        dstTexture: MTLTexture
    ) async throws {
        guard
            let commandBuffer = renderer?.newCommandBuffer else {
            return
        }

        renderer?.copyTexture(
            srctexture: srcTexture,
            dstTexture: dstTexture,
            with: commandBuffer
        )

        try await commandBuffer.commitAndWaitAsync()
    }

    /// Updates `selectedTexture` and `unselectedBottomTexture`, `unselectedTopTexture`.
    /// This textures are pre-merged from `textureRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    public func updateSelectedTexture(
        textureLayers: any TextureLayersProtocol,
        textureRepository: TextureRepository
    ) async throws {
        guard
            let renderer,
            let selectedLayer = textureLayers.selectedLayer,
            let selectedIndex = textureLayers.selectedIndex,
            let newCommandBuffer = renderer.newCommandBuffer
        else {
            return
        }

        let bottomLayers = bottomLayers(
            selectedIndex: selectedIndex,
            layers: textureLayers.layers.map { .init(item: $0) }
        )

        // The selected texture is kept opaque here because transparency is applied when used
        let opaqueLayer: TextureLayerModel = .init(
            id: selectedLayer.id,
            title: selectedLayer.title,
            alpha: 255,
            isVisible: selectedLayer.isVisible
        )

        let topLayers = topLayers(
            selectedIndex: selectedIndex,
            layers: textureLayers.layers.map { .init(item: $0) }
        )

        renderer.clearTexture(texture: unselectedBottomTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: selectedLayerTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: unselectedTopTexture, with: newCommandBuffer)

        let textures = try await textureRepository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
        )

        try await drawLayerTextures(
            textures: textures,
            layers: bottomLayers,
            on: unselectedBottomTexture,
            with: newCommandBuffer
        )

        try await drawLayerTextures(
            textures: textures,
            layers: [opaqueLayer],
            on: selectedLayerTexture,
            with: newCommandBuffer
        )

        try await drawLayerTextures(
            textures: textures,
            layers: topLayers,
            on: unselectedTopTexture,
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()
    }

    /// Updates the canvas using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    public func updateCanvasView(
        realtimeDrawingTexture: MTLTexture? = nil,
        selectedLayer: TextureLayerModel
    ) {
        guard
            let renderer,
            let commandBuffer = displayView?.commandBuffer,
            let canvasTexture
        else { return }

        renderer.fillColor(
            texture: canvasTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: unselectedBottomTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        if selectedLayer.isVisible {
            renderer.mergeTexture(
                texture: realtimeDrawingTexture ?? selectedLayerTexture,
                alpha: selectedLayer.alpha,
                into: canvasTexture,
                with: commandBuffer
            )
        }

        renderer.mergeTexture(
            texture: unselectedTopTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        updateCanvasView()
    }

    public func updateCanvasView() {
        guard
            let renderer,
            let commandBuffer = displayView?.commandBuffer,
            let displayTexture = displayView?.displayTexture
        else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: baseBackgroundColor,
            on: displayTexture,
            with: commandBuffer
        )
        displayView?.setNeedsDisplay()
    }
}

extension CanvasRenderer {
    private func bottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    private func topLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    private func drawLayerTextures(
        textures: [IdentifiedTexture],
        layers: [TextureLayerModel],
        on destination: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let renderer else { return }

        let textureDictionary = IdentifiedTexture.dictionary(from: Set(textures))

        for layer in layers {
            if let resultTexture = textureDictionary[layer.id] {
                renderer.mergeTexture(
                    texture: resultTexture,
                    alpha: layer.alpha,
                    into: destination,
                    with: commandBuffer
                )
            }
        }
    }
}
