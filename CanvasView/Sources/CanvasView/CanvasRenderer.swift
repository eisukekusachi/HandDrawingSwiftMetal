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

    public var commandBuffer: MTLCommandBuffer? {
        displayView?.commandBuffer
    }

    /// The texture that combines the background color and the textures of `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`
    private(set) var canvasTexture: MTLTexture?

    /// The texture of the selected layer
    private(set) var selectedLayerTexture: MTLTexture?

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    private var frameSize: CGSize = .zero

    private var matrix: CGAffineTransform = .identity

    private var renderer: MTLRendering?

    /// The background color of the canvas
    private var backgroundColor: UIColor = .white

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    private var baseBackgroundColor: UIColor = .lightGray

    private var displayView: CanvasDisplayable?

    private var flippedTextureBuffers: MTLTextureBuffers?

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture?

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture?

    private var cancellables = Set<AnyCancellable>()

    public init(
        renderer: MTLRendering
    ) {
        self.renderer = renderer
    }

    public func initialize(
        displayView: CanvasDisplayable?,
        environmentConfiguration: EnvironmentConfiguration?
    ) {
        guard let renderer else { return }

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        )

        self.displayView = displayView

        if let backgroundColor = environmentConfiguration?.backgroundColor {
            self.backgroundColor = backgroundColor
        }
        if let baseBackgroundColor = environmentConfiguration?.baseBackgroundColor {
            self.baseBackgroundColor = baseBackgroundColor
        }
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
            let unselectedBottomTexture = makeTexture(textureSize),
            let selectedLayerTexture = makeTexture(textureSize),
            let unselectedTopTexture = makeTexture(textureSize),
            let canvasTexture = makeTexture(textureSize),
            let realtimeDrawingTexture = makeTexture(textureSize)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.unselectedBottomTexture = unselectedBottomTexture
        self.selectedLayerTexture = selectedLayerTexture
        self.unselectedTopTexture = unselectedTopTexture
        self.canvasTexture = canvasTexture
        self.realtimeDrawingTexture = realtimeDrawingTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.selectedLayerTexture?.label = "selectedLayerTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"
        self.canvasTexture?.label = "canvasTexture"
        self.realtimeDrawingTexture?.label = "realtimeDrawingTexture"
    }
}

extension CanvasRenderer {

    public func setFrameSize(_ size: CGSize) {
        self.frameSize = size
    }

    public func setMatrix(_ matrix: CGAffineTransform) {
        self.matrix = matrix
    }

    /// Updates `selectedTexture` and `unselectedBottomTexture`, `unselectedTopTexture`, `realtimeDrawingTexture`.
    /// This textures are pre-merged from `textureRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    public func updateTextures(
        textureLayers: any TextureLayersProtocol,
        textureDocumentsDirectoryRepository: TextureDocumentsDirectoryRepository
    ) async throws {
        guard
            let renderer,
            let unselectedBottomTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let unselectedTopTexture,
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
        renderer.clearTexture(texture: realtimeDrawingTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: unselectedTopTexture, with: newCommandBuffer)

        // Get textures from the Documents directory
        let textures = try await textureDocumentsDirectoryRepository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
        )

        // Update the class’s textures with the retrieved textures
        try await drawTextures(
            repositoryTextures: textures,
            using: bottomLayers,
            on: unselectedBottomTexture,
            with: newCommandBuffer
        )

        try await drawTextures(
            repositoryTextures: textures,
            using: [opaqueLayer],
            on: selectedLayerTexture,
            with: newCommandBuffer
        )

        try await drawTextures(
            repositoryTextures: textures,
            using: topLayers,
            on: unselectedTopTexture,
            with: newCommandBuffer
        )

        renderer.copyTexture(
            srcTexture: selectedLayerTexture,
            dstTexture: realtimeDrawingTexture,
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()
    }

    func renderRealtimeDrawingTextureToSelectedLayer(
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let renderer,
            let flippedTextureBuffers,
            let realtimeDrawingTexture,
            let selectedLayerTexture
        else { return }

        renderer.drawTexture(
            texture: realtimeDrawingTexture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: selectedLayerTexture,
            with: commandBuffer
        )
    }

    /// Commits the command buffer and refreshes the entire screen using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    public func commitAndRefreshDisplay(
        displayRealtimeDrawingTexture: Bool,
        selectedLayer: TextureLayerItem
    ) {
        guard
            let renderer,
            let canvasTexture,
            let unselectedBottomTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let unselectedTopTexture,
            let commandBuffer = displayView?.commandBuffer
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
                texture: displayRealtimeDrawingTexture ? realtimeDrawingTexture : selectedLayerTexture,
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

        commitAndRefreshDisplay()
    }

    /// Commits the command buffer and refreshes the entire screen
    public func commitAndRefreshDisplay() {
        guard
            let renderer,
            let displayTexture = displayView?.displayTexture,
            let commandBuffer = displayView?.commandBuffer
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

    public func resetCommandBuffer() {
        displayView?.resetCommandBuffer()
    }
}

extension CanvasRenderer {
    private func bottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    private func topLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    private func drawTextures(
        repositoryTextures: [IdentifiedTexture],
        using layers: [TextureLayerModel],
        on destination: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let renderer else { return }

        let textureDictionary = IdentifiedTexture.dictionary(
            from: Set(repositoryTextures)
        )

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

    private func makeTexture(_ textureSize: CGSize) -> MTLTexture? {
        guard let device else { return nil }
        return MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
    }
}
