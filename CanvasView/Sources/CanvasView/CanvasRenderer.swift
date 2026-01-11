//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
@preconcurrency import MetalKit

/// A class that renders textures from `TextureLayersDocumentsRepository` onto the texture of `displayView`
@MainActor
public final class CanvasRenderer: ObservableObject {

    public var device: MTLDevice {
        renderer.device
    }

    public var commandBuffer: MTLCommandBuffer? {
        displayView.commandBuffer
    }

    public var textureSize: CGSize? {
        canvasTexture?.size
    }

    public var displayTextureSize: CGSize? {
        displayView.displayTexture?.size
    }

    public let textureLayersDocumentsRepository: TextureLayersDocumentsRepositoryProtocol

    /// The texture that combines the background color and the textures of `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`
    private(set) var canvasTexture: MTLTexture?

    /// The texture of the selected layer
    private(set) var selectedLayerTexture: MTLTexture?

    /// Texture used during drawing
    private(set) var realtimeDrawingTexture: RealtimeDrawingTexture?

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture?

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers

    private var frameSize: CGSize = .zero

    private var matrix: CGAffineTransform = .identity

    private let renderer: MTLRendering

    private let displayView: CanvasDisplayable

    /// The background color of the canvas
    private var backgroundColor: UIColor = .white

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    private var baseBackgroundColor: UIColor = .lightGray

    private var cancellables = Set<AnyCancellable>()

    public init(
        renderer: MTLRendering,
        repository: TextureLayersDocumentsRepositoryProtocol,
        displayView: CanvasDisplayable
    ) {
        guard let buffer = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        ) else {
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = renderer
        self.textureLayersDocumentsRepository = repository
        self.displayView = displayView
        self.flippedTextureBuffers = buffer
    }

    public func setup(
        backgroundColor: UIColor?,
        baseBackgroundColor: UIColor?
    ) {
        if let backgroundColor {
            self.backgroundColor = backgroundColor
        }
        if let baseBackgroundColor {
            self.baseBackgroundColor = baseBackgroundColor
        }
    }

    public func initializeTextures(textureSize: CGSize) throws {
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
            let unselectedBottomTexture = makeTexture(textureSize),
            let selectedLayerTexture = makeTexture(textureSize),
            let unselectedTopTexture = makeTexture(textureSize),
            let canvasTexture = makeTexture(textureSize),
            let realtimeDrawingTexture = makeTexture(textureSize)
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

    /// Updates `selectedTexture` and `realtimeDrawingTexture`, `unselectedBottomTexture`, `unselectedTopTexture`.
    /// This textures are pre-merged from `TextureLayersDocumentsRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    public func updateTextures(
        context: CanvasTextureLayersContext
    ) async throws {
        guard
            let unselectedBottomTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let unselectedTopTexture,
            let newCommandBuffer = renderer.newCommandBuffer
        else {
            return
        }

        let bottomLayers = bottomLayers(
            selectedIndex: context.selectedIndex,
            layers: context.layers
        )

        // The selected texture is kept opaque here because transparency is applied when used
        let opaqueLayer: TextureLayerModel = .init(
            id: context.selectedLayer.id,
            title: context.selectedLayer.title,
            alpha: 255,
            isVisible: context.selectedLayer.isVisible
        )

        let topLayers = topLayers(
            selectedIndex: context.selectedIndex,
            layers: context.layers
        )

        renderer.clearTexture(texture: unselectedBottomTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: selectedLayerTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: realtimeDrawingTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: unselectedTopTexture, with: newCommandBuffer)

        // Get textures from the Documents directory
        let textures = try await textureLayersDocumentsRepository.duplicatedTextures(
            context.layers.map { $0.id }
        )

        // Update the class’s textures with the retrieved textures
        drawTextures(
            repositoryTextures: textures,
            using: bottomLayers,
            on: unselectedBottomTexture,
            with: newCommandBuffer
        )

        drawTextures(
            repositoryTextures: textures,
            using: [opaqueLayer],
            on: selectedLayerTexture,
            with: newCommandBuffer
        )

        drawTextures(
            repositoryTextures: textures,
            using: topLayers,
            on: unselectedTopTexture,
            with: newCommandBuffer
        )

        // Make selectedLayerTexture and realtimeDrawingTexture contain the same pixels
        renderer.copyTexture(
            srcTexture: selectedLayerTexture,
            dstTexture: realtimeDrawingTexture,
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()
    }

    /// Updates `selectedLayerTexture` and `realtimeDrawingTexture`
    public func updateDrawingTexture(
        using texture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let selectedLayerTexture,
            let realtimeDrawingTexture
        else { return }

        renderer.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: selectedLayerTexture,
            with: commandBuffer
        )

        // Make selectedLayerTexture and realtimeDrawingTexture contain the same pixels
        renderer.copyTexture(
            srcTexture: selectedLayerTexture,
            dstTexture: realtimeDrawingTexture,
            with: commandBuffer
        )
    }

    func updateSelectedLayerTexture(
        using texture: RealtimeDrawingTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let texture,
            let selectedLayerTexture
        else { return }

        renderer.drawTexture(
            texture: texture,
            buffers: flippedTextureBuffers,
            withBackgroundColor: .clear,
            on: selectedLayerTexture,
            with: commandBuffer
        )
    }

    /// Commits the command buffer and refreshes the entire screen using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    public func composeAndRefreshCanvas(
        useRealtimeDrawingTexture: Bool,
        selectedLayer: TextureLayerModel
    ) {
        guard
            let canvasTexture,
            let unselectedBottomTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let unselectedTopTexture,
            let commandBuffer = displayView.commandBuffer
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
                texture: useRealtimeDrawingTexture ? realtimeDrawingTexture : selectedLayerTexture,
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

        refreshCanvas()
    }

    /// Commits the command buffer and refreshes the entire screen
    public func refreshCanvas() {
        guard
            let displayTexture = displayView.displayTexture,
            let commandBuffer = displayView.commandBuffer
        else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: baseBackgroundColor,
            on: displayTexture,
            with: commandBuffer
        )
        displayView.setNeedsDisplay()
    }

    public func resetCommandBuffer() {
        displayView.resetCommandBuffer()
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
    ) {
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
        MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: device
        )
    }
}

@MainActor
public struct CanvasTextureLayersContext {
    let selectedLayer: TextureLayerModel
    let selectedIndex: Int
    let layers: [TextureLayerModel]

    init?(textureLayers: any TextureLayersProtocol) {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let selectedIndex = textureLayers.selectedIndex
        else { return nil }
        self.selectedLayer = .init(item: selectedLayer)
        self.selectedIndex = selectedIndex
        self.layers = textureLayers.layers.map { .init(item: $0) }
    }
}
