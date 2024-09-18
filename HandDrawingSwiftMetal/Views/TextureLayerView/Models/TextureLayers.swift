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

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

}

extension TextureLayers {
    /// Merge the textures of layers on a single texture with the backgroundColor
    func mergeAllTextures(
        usingCurrentTexture currentTexture: CanvasCurrentTexture? = nil,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let destinationTexture
        else { return }

        MTLRenderer.fill(
            destinationTexture,
            withRGB: backgroundColor.rgb,
            commandBuffer
        )

        MTLRenderer.merge(
            texture: bottomTexture,
            into: destinationTexture,
            commandBuffer
        )

        if layers[index].isVisible {
            if let currentTexture {
                MTLRenderer.merge(
                    texture: currentTexture.currentTexture,
                    alpha: layers[index].alpha,
                    into: destinationTexture,
                    commandBuffer
                )
            } else {
                MTLRenderer.merge(
                    texture: layers[index].texture,
                    alpha: layers[index].alpha,
                    into: destinationTexture,
                    commandBuffer
                )
            }
        }

        MTLRenderer.merge(
            texture: topTexture,
            into: destinationTexture,
            commandBuffer
        )
    }

    func initLayers(
        newLayers: [TextureLayer] = [],
        layerIndex: Int = 0,
        textureSize: CGSize
    ) {
        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        var newLayers = newLayers
        if newLayers.isEmpty {
            newLayers.append(
                .init(
                    texture: MTKTextureUtils.makeBlankTexture(device, textureSize),
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
        to commandBuffer: MTLCommandBuffer
    ) {
        let bottomIndex: Int = index - 1
        let topIndex: Int = index + 1

        MTLRenderer.clear(texture: bottomTexture, commandBuffer)
        MTLRenderer.clear(texture: topTexture, commandBuffer)

        if bottomIndex >= 0 {
            for i in 0 ... bottomIndex where layers[i].isVisible {
                MTLRenderer.merge(
                    texture: layers[i].texture,
                    alpha: layers[i].alpha,
                    into: bottomTexture,
                    commandBuffer
                )
            }
        }
        if topIndex < layers.count {
            for i in topIndex ..< layers.count where layers[i].isVisible {
                MTLRenderer.merge(
                    texture: layers[i].texture,
                    alpha: layers[i].alpha,
                    into: topTexture,
                    commandBuffer
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
            let newTexture = MTKTextureUtils.duplicateTexture(device, layers[index].texture)
        else { return }

        layers[index].texture = newTexture
    }

}
