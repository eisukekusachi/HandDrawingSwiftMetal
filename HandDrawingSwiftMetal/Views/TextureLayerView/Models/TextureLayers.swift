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
    private var bottomTexture: MTLTexture?
    /// A texture that combines the textures of all layers above the selected layer
    private var topTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers?

    var isTextureInitialized: Bool {
        bottomTexture != nil && topTexture != nil
    }

    var backgroundColor: UIColor = .white

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    override init() {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )
    }

    func initLayers(
        layers: [TextureLayer] = [],
        layerIndex: Int = 0
    ) {
        guard
            let size = layers.first?.texture?.size,
            let bottomTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device),
            let topTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
        else {
            bottomTexture = nil
            topTexture = nil
            return
        }

        self.bottomTexture = bottomTexture
        self.topTexture = topTexture

        initLayers(
            index: layerIndex,
            layers: layers
        )
    }

    func initLayers(size: CGSize) {
        guard
            size > MTLRenderer.minimumTextureSize,
            let bottomTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device),
            let topTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device),
            let texture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.bottomTexture = bottomTexture
        self.topTexture = topTexture

        initLayers(
            index: 0,
            layers: [
                .init(
                    texture: texture,
                    title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
                )
            ]
        )
    }

}

extension TextureLayers {
    /// Draws the textures of layers on `destinationTexture` with the backgroundColor
    func drawAllTextures(
        usingCurrentTexture currentTexture: MTLTexture? = nil,
        allLayerUpdates: Bool = false,
        on destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let bottomTexture,
            let topTexture,
            let destinationTexture
        else {
            Logger.standard.error("TextureLayers's textures are nil")
            return
        }

        // Combine the textures of unselected layers into `topTexture` and `bottomTexture`
        if allLayerUpdates {
            MTLRenderer.shared.clearTexture(texture: bottomTexture, with: commandBuffer)
            MTLRenderer.shared.clearTexture(texture: topTexture, with: commandBuffer)

            if index > 0 {
                mergeLayerTextures(range: 0 ... index - 1, into: bottomTexture, with: commandBuffer)
            }
            if index < layers.count - 1 {
                mergeLayerTextures(range: index + 1 ... layers.count - 1, into: topTexture, with: commandBuffer)
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

        if layers[index].isVisible, let texture = currentTexture ?? layers[index].texture {
            MTLRenderer.shared.mergeTexture(
                texture: texture,
                alpha: layers[index].alpha,
                on: destinationTexture,
                with: commandBuffer
            )
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

extension TextureLayers {

    private func mergeLayerTextures(
        range: ClosedRange<Int>,
        into targetTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        layers[range]
            .filter { $0.isVisible }
            .compactMap { layer -> (MTLTexture, Int)? in
                guard let texture: MTLTexture = layer.texture else { return nil }
                return (texture, layer.alpha)
            }
            .forEach { result in
                MTLRenderer.shared.mergeTexture(
                    texture: result.0,
                    alpha: result.1,
                    on: targetTexture,
                    with: commandBuffer
                )
            }
    }

}
