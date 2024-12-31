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

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

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
        shouldUpdateAllLayers: Bool = false,
        backgroundColor: UIColor,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let destinationTexture
        else { return }

        // Combine the textures of unselected layers into `topTexture` and `bottomTexture`
        if shouldUpdateAllLayers {
            let bottomIndex: Int = index - 1
            let topIndex: Int = index + 1

            MTLRenderer.clearTexture(texture: bottomTexture, with: commandBuffer)
            MTLRenderer.clearTexture(texture: topTexture, with: commandBuffer)

            if bottomIndex >= 0 {
                for i in 0 ... bottomIndex where layers[i].isVisible {
                    MTLRenderer.mergeTextures(
                        sourceTexture: layers[i].texture,
                        sourceAlpha: layers[i].alpha,
                        destinationTexture: bottomTexture,
                        with: commandBuffer
                    )
                }
            }
            if topIndex < layers.count {
                for i in topIndex ..< layers.count where layers[i].isVisible {
                    MTLRenderer.mergeTextures(
                        sourceTexture: layers[i].texture,
                        sourceAlpha: layers[i].alpha,
                        destinationTexture: topTexture,
                        with: commandBuffer
                    )
                }
            }
        }

        MTLRenderer.fillTexture(
            texture: destinationTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        MTLRenderer.mergeTextures(
            sourceTexture: bottomTexture,
            destinationTexture: destinationTexture,
            with: commandBuffer
        )

        if layers[index].isVisible {
            if let currentTexture {
                MTLRenderer.mergeTextures(
                    sourceTexture: currentTexture,
                    sourceAlpha: layers[index].alpha,
                    destinationTexture: destinationTexture,
                    with: commandBuffer
                )

            } else {
                MTLRenderer.mergeTextures(
                    sourceTexture: layers[index].texture,
                    sourceAlpha: layers[index].alpha,
                    destinationTexture: destinationTexture,
                    with: commandBuffer
                )
            }
        }

        MTLRenderer.mergeTextures(
            sourceTexture: topTexture,
            destinationTexture: destinationTexture,
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

    func updateIndex(_ layer: TextureLayer?) {
        guard let layer, let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
    }

    /// Sort TextureLayers's `layers` based on the values received from `List`
    func moveLayer(
        fromListOffsets: IndexSet,
        toListOffset: Int
    ) {
        guard let selectedLayer else { return }

        // Since `textureLayers` and `List` have reversed orders,
        // reverse the array, perform move operations, and then reverse it back
        reverseLayers()
        moveLayer(
            fromOffsets: fromListOffsets,
            toOffset: toListOffset
        )
        reverseLayers()

        updateIndex(selectedLayer)
    }

}
