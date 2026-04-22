//
//  TextureLayerCanvasRenderer.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/02/05.
//

import CanvasView
import TextureLayerView

@preconcurrency import MetalKit

@MainActor
final class TextureLayerCanvasRenderer {

    var backgroundColor: UIColor = .white

    private let renderer: MTLRendering

    init(
        renderer: MTLRendering,
    ) {
        self.renderer = renderer
    }

    func renderLayersIntoTextures(
        layers: [TextureLayerModel],
        textureRepository: TextureLayersDocumentsRepositoryProtocol,
        on destinationTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let destinationTexture else { return }

        let textures = try await textureRepository.duplicatedTextures(
            layers.map { $0.id },
            textureSize: destinationTexture.size,
            device: renderer.device
        )
        let textureDictionary = Dictionary(uniqueKeysWithValues: textures)

        renderer.clearTexture(
            texture: destinationTexture,
            with: commandBuffer
        )

        for layer in layers {
            if let texture = textureDictionary[layer.id] {
                renderer.mergeTexture(
                    texture: texture,
                    alpha: layer.alpha,
                    into: destinationTexture,
                    with: commandBuffer
                )
            } else {
                let message = "id: \(layer.id.uuidString)"
                Logger.error(
                    String(format: String(localized: "Unable to find %@"), message)
                )
            }
        }
    }

    /// Refreshes the entire screen using textures
    func renderCanvas(
        unselectedTopTexture: MTLTexture?,
        currentTextureLayer: TextureLayer,
        unselectedBottomTexture: MTLTexture?,
        canvasTexture: MTLTexture?,
        commandBuffer: MTLCommandBuffer?
    ) {
        guard
            let unselectedTopTexture,
            let unselectedBottomTexture,
            let canvasTexture,
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

        if currentTextureLayer.isVisible,
           let texture = currentTextureLayer.texture {
            renderer.mergeTexture(
                texture: texture,
                alpha: currentTextureLayer.alpha,
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
}
