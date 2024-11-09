//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
/// Manages `TextureLayer` and the textures used for rendering
final class TextureLayers: LayerManager<TextureLayer> {
    /// A texture that combines the textures of all layers below the selected layer
    private var bottomTexture: MTLTexture!
    /// A texture that combines the textures of all layers above the selected layer
    private var topTexture: MTLTexture!

    private var temporaryTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    override init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

}

extension TextureLayers {
    /// Merge the textures of layers on a single texture with the backgroundColor
    func mergeAllTextures(
        usingCurrentTexture currentTexture: MTLTexture? = nil,
        shouldUpdateAllLayers: Bool = false,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let flippedTextureBuffers,
            let destinationTexture
        else { return }

        if shouldUpdateAllLayers {
            updateUnselectedLayers(with: commandBuffer)
        }

        MTLRenderer.fillTexture(
            texture: destinationTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        MTLRenderer.mergeTextures(
            sourceTexture: bottomTexture,
            destinationTexture: destinationTexture,
            temporaryTexture: temporaryTexture,
            temporaryTextureBuffers: flippedTextureBuffers,
            with: commandBuffer
        )

        if layers[index].isVisible {
            if let currentTexture {
                MTLRenderer.mergeTextures(
                    sourceTexture: currentTexture,
                    destinationTexture: destinationTexture,
                    alpha: layers[index].alpha,
                    temporaryTexture: temporaryTexture,
                    temporaryTextureBuffers: flippedTextureBuffers,
                    with: commandBuffer
                )

            } else {
                MTLRenderer.mergeTextures(
                    sourceTexture: layers[index].texture,
                    destinationTexture: destinationTexture,
                    alpha: layers[index].alpha,
                    temporaryTexture: temporaryTexture,
                    temporaryTextureBuffers: flippedTextureBuffers,
                    with: commandBuffer
                )
            }
        }

        MTLRenderer.mergeTextures(
            sourceTexture: topTexture,
            destinationTexture: destinationTexture,
            temporaryTexture: temporaryTexture,
            temporaryTextureBuffers: flippedTextureBuffers,
            with: commandBuffer
        )
    }

    func initLayers(
        newLayers: [TextureLayer] = [],
        layerIndex: Int = 0,
        textureSize: CGSize
    ) {
        bottomTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        topTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)
        temporaryTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device)

        var newLayers = newLayers
        if newLayers.isEmpty,
           let newTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device
           ) {
            newLayers.append(
                .init(
                    texture: newTexture,
                    title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
                )
            )
        }

        super.initLayers(
            index: layerIndex,
            layers: newLayers
        )
    }

}

extension TextureLayers {
    /// Combine the textures of unselected layers into `topTexture` and `bottomTexture`
    func updateUnselectedLayers(
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let flippedTextureBuffers else { return }

        let bottomIndex: Int = index - 1
        let topIndex: Int = index + 1

        MTLRenderer.clearTexture(texture: bottomTexture, with: commandBuffer)
        MTLRenderer.clearTexture(texture: topTexture, with: commandBuffer)

        if bottomIndex >= 0 {
            for i in 0 ... bottomIndex where layers[i].isVisible {
                MTLRenderer.mergeTextures(
                    sourceTexture: layers[i].texture,
                    destinationTexture: bottomTexture,
                    alpha: layers[i].alpha,
                    temporaryTexture: temporaryTexture,
                    temporaryTextureBuffers: flippedTextureBuffers,
                    with: commandBuffer
                )
            }
        }
        if topIndex < layers.count {
            for i in topIndex ..< layers.count where layers[i].isVisible {
                MTLRenderer.mergeTextures(
                    sourceTexture: layers[i].texture,
                    destinationTexture: topTexture,
                    alpha: layers[i].alpha,
                    temporaryTexture: temporaryTexture,
                    temporaryTextureBuffers: flippedTextureBuffers,
                    with: commandBuffer
                )
            }
        }
    }

    func updateLayer(
        index: Int,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard index < layers.count else { return }
        if let title {
            layers[index].title = title
        }
        if let isVisible {
            layers[index].isVisible = isVisible
        }

        if let alpha {
            layers[index].alpha = alpha
        }
    }

    func updateThumbnail(index: Int) {
        guard index < layers.count else { return }
        layers[index].updateThumbnail()
    }

    /// Update the currently selected texture with a new instance
    func updateSelectedTextureAddress() {
        guard 
            let newTexture = MTLTextureCreator.duplicateTexture(
                texture: layers[index].texture,
                with: device
            )
        else { return }

        layers[index].texture = newTexture
    }

}
