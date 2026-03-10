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

    public func initializeTextures(textureSize: CGSize) throws {
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
            let unselectedBottomTexture = renderer.makeTexture(textureSize),
            let unselectedTopTexture = renderer.makeTexture(textureSize)
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

    public func getTexture(
        id: LayerId,
        repository: TextureLayersDocumentsRepositoryProtocol?
    ) async throws -> IdentifiedTexture? {
        try await repository?.duplicatedTexture(id)
    }

    /// Refreshes `selectedLayerTexture` and `realtimeDrawingTexture`, `unselectedBottomTexture`, `unselectedTopTexture`.
    /// This textures are pre-merged from `TextureLayersDocumentsRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    public func refreshTexturesFromRepository(
        textureLayers: TextureLayersRenderContext,
        repository: TextureLayersDocumentsRepositoryProtocol?
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
            selectedIndex: textureLayers.selectedIndex,
            layers: textureLayers.layers
        )

        let topLayers = topLayers(
            selectedIndex: textureLayers.selectedIndex,
            layers: textureLayers.layers
        )

        renderer.clearTexture(texture: unselectedBottomTexture, with: newCommandBuffer)
        renderer.clearTexture(texture: unselectedTopTexture, with: newCommandBuffer)

        // Get textures from the Documents directory
        let textures = try await repository.duplicatedTextures(
            textureLayers.layers.map { $0.id }
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
    public func updateCanvasTexture(
        textureLayer: TextureLayerRenderContext,
        canvasTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let canvasTexture,
            let unselectedBottomTexture,
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

        if textureLayer.isVisible,
           let texture = textureLayer.texture {
            renderer.mergeTexture(
                texture: texture,
                alpha: textureLayer.alpha,
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
}
