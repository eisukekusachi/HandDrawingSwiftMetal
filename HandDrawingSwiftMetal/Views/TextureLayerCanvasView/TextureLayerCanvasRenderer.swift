//
//  Created by Eisuke Kusachi
//

import CanvasView
import Core
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
        layers: [TextureLayerItem],
        textureRepository: MTLTextureDataRepositoryProtocol,
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
        selectedTextureLayer: SelectedTextureLayer,
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
            color: backgroundColor,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: unselectedBottomTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        if selectedTextureLayer.isVisible,
           let texture = selectedTextureLayer.texture {
            renderer.mergeTexture(
                texture: texture,
                alpha: selectedTextureLayer.alpha,
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
