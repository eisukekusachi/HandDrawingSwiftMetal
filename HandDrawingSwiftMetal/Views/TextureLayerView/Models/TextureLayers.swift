//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit

/// Manages `TextureLayer` and the textures used for rendering
final class TextureLayers: Layers<TextureLayer> {
    /// A texture that combines the textures of all layers below the selected layer
    private var bottomTexture: MTLTexture!
    /// A texture that combines the textures of all layers above the selected layer
    private var topTexture: MTLTexture!

    private var temporaryTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    override init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

    func initLayers(
        size: CGSize,
        layers: [TextureLayer] = [],
        layerIndex: Int = 0
    ) {
        bottomTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
        topTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
        temporaryTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device)

        if layers.isEmpty,
           let texture = MTLTextureCreator.makeBlankTexture(
            size: size,
            with: device
           ) {
            initLayers(
                index: layerIndex,
                layers: [
                    .init(
                        texture: texture,
                        title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
                    )
                ]
            )
        } else {
            initLayers(
                index: layerIndex,
                layers: layers
            )
        }
    }

}

extension TextureLayers {
    /// Merge the textures of layers on a single texture with the backgroundColor
    func mergeAllTextures(
        usingCurrentTexture currentTexture: MTLTexture? = nil,
        withAllLayerUpdates allUpdates: Bool = false,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let destinationTexture
        else { return }

        // Combine the textures of unselected layers into `topTexture` and `bottomTexture`
        if allUpdates {
            let bottomIndex: Int = index - 1
            let topIndex: Int = index + 1

            MTLRenderer.shared.clearTexture(texture: bottomTexture, with: commandBuffer)
            MTLRenderer.shared.clearTexture(texture: topTexture, with: commandBuffer)

            if bottomIndex >= 0 {
                for i in 0 ... bottomIndex where layers[i].isVisible {
                    if let texture = layers[i].texture {
                        MTLRenderer.shared.mergeTexture(
                            texture: texture,
                            alpha: layers[i].alpha,
                            on: bottomTexture,
                            with: commandBuffer
                        )
                    }
                }
            }
            if topIndex < layers.count {
                for i in topIndex ..< layers.count where layers[i].isVisible {
                    if let texture = layers[i].texture {
                        MTLRenderer.shared.mergeTexture(
                            texture: texture,
                            alpha: layers[i].alpha,
                            on: topTexture,
                            with: commandBuffer
                        )
                    }
                }
            }
        }

        MTLRenderer.shared.fillTexture(
            texture: destinationTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        MTLRenderer.shared.mergeTexture(
            texture: bottomTexture,
            on: destinationTexture,
            with: commandBuffer
        )

        if layers[index].isVisible {
            if let currentTexture {
                MTLRenderer.shared.mergeTexture(
                    texture: currentTexture,
                    alpha: layers[index].alpha,
                    on: destinationTexture,
                    with: commandBuffer
                )

            } else if let texture = layers[index].texture {
                MTLRenderer.shared.mergeTexture(
                    texture: texture,
                    alpha: layers[index].alpha,
                    on: destinationTexture,
                    with: commandBuffer
                )
            }
        }

        MTLRenderer.shared.mergeTexture(
            texture: topTexture,
            on: destinationTexture,
            with: commandBuffer
        )
    }

}

extension TextureLayers {
    func updateLayer(
        index: Int,
        title: String? = nil,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard layers.indices.contains(index) else { return }

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
        guard layers.indices.contains(index) else { return }
        layers[index].updateThumbnail()
    }

    func updateIndex(_ layer: TextureLayer?) {
        guard let layer, let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
    }

    /// Sort TextureLayers's `layers` based on the values received from `List`
    func moveLayer(
        fromListOffsets: IndexSet,
        toListOffset: Int
    ) {
        // Since `textureLayers` and `List` have reversed orders,
        // reverse the array, perform move operations, and then reverse it back
        reverseLayers()
        moveLayer(
            fromOffsets: fromListOffsets,
            toOffset: toListOffset
        )
        reverseLayers()
    }

}
