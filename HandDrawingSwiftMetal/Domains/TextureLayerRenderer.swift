//
//  TextureLayerRenderer.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/02/05.
//

import CanvasView
import UIKit

@preconcurrency import MetalKit

@MainActor
public struct CanvasTextureLayersContext {
    public let selectedLayer: TextureLayerModel
    public let selectedIndex: Int
    public let layers: [TextureLayerModel]
    public init?(textureLayers: any TextureLayersProtocol) {
        guard
            let selectedLayer = textureLayers.selectedLayer,
            let selectedIndex = textureLayers.selectedIndex
        else { return nil }
        self.selectedLayer = .init(item: selectedLayer)
        self.selectedIndex = selectedIndex
        self.layers = textureLayers.layers.map { .init(item: $0) }
    }
}

@MainActor
public class TextureLayerRenderer {

    public var backgroundColor: UIColor = .white

    /// Texture that combines the textures of all layers below the selected layer
    private var unselectedBottomTexture: MTLTexture?

    /// Texture that combines the textures of all layers above the selected layer
    private var unselectedTopTexture: MTLTexture?

    private let renderer: MTLRendering

    /// Buffers used to draw textures with vertical flipping
    private let flippedTextureBuffers: MTLTextureBuffers

    public init(
        renderer: MTLRendering,
    ) {
        guard let buffer = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: renderer.device
        ) else {
            fatalError("Metal is not supported on this device.")
        }
        self.renderer = renderer
        self.flippedTextureBuffers = buffer
    }

    public func setupTextures(textureSize: CGSize) throws {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)"
                )
            )
            Logger.error(error)
            throw error
        }

        guard
            let unselectedBottomTexture = makeTexture(textureSize),
            let unselectedTopTexture = makeTexture(textureSize)
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(
                    localized: "Failed to create new texture"
                )
            )
            Logger.error(error)
            throw error
        }
        self.unselectedBottomTexture = unselectedBottomTexture
        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.unselectedTopTexture = unselectedTopTexture
        self.unselectedTopTexture?.label = "unselectedTopTexture"
    }

    /// Refreshes `selectedLayerTexture` and `realtimeDrawingTexture`, `unselectedBottomTexture`, `unselectedTopTexture`.
    /// This textures are pre-merged from `TextureLayersDocumentsRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    public func refreshTexturesFromRepository(
        repository: TextureLayersDocumentsRepositoryProtocol?,
        context: CanvasTextureLayersContext
    ) async throws {
        guard
            let repository,
            let unselectedBottomTexture,
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
        renderer.clearTexture(texture: unselectedTopTexture, with: newCommandBuffer)

        // Get textures from the Documents directory
        let textures = try await repository.duplicatedTextures(
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
            using: topLayers,
            on: unselectedTopTexture,
            with: newCommandBuffer
        )

        try await newCommandBuffer.commitAndWaitAsync()
    }

    /// Refreshes the entire screen using textures
    public func refreshCanvas(
        useRealtimeDrawingTexture: Bool,
        selectedLayer: TextureLayerModel,
        selectedLayerTexture: MTLTexture?,
        realtimeDrawingTexture: MTLTexture?,
        canvasTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let canvasTexture,
            let unselectedBottomTexture,
            let selectedLayerTexture,
            let realtimeDrawingTexture,
            let unselectedTopTexture,
            let commandBuffer
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
    }

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
            } else {
                let message = "id: \(layer.id.uuidString)"
                Logger.error(String(format: String(localized: "Unable to find %@"), message))
            }
        }
    }

    private func makeTexture(_ textureSize: CGSize) -> MTLTexture? {
        MTLTextureCreator.makeTexture(
            width: Int(textureSize.width),
            height: Int(textureSize.height),
            with: renderer.device
        )
    }
}
