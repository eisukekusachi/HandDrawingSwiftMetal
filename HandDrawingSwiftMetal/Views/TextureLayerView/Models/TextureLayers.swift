//
//  TextureLayers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
/// Manages `TextureLayer` and the textures used for rendering
final class TextureLayers: Layers<TextureLayer> {

    var isTextureInitialized: Bool {
        unselectedBottomTexture != nil && unselectedTopTexture != nil
    }

    var backgroundColor: UIColor = .white

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private let renderer: MTLRendering!

    /// A texture that combines the textures of all layers below the selected layer
    private var unselectedBottomTexture: MTLTexture?
    /// A texture that combines the textures of all layers above the selected layer
    private var unselectedTopTexture: MTLTexture?

    private var flippedTextureBuffers: MTLTextureBuffers?

    init(renderer: MTLRendering = MTLRenderer.shared) {
        self.renderer = renderer

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
            unselectedBottomTexture = nil
            unselectedTopTexture = nil
            return
        }

        self.unselectedBottomTexture = bottomTexture
        self.unselectedTopTexture = topTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"

        initLayers(
            index: layerIndex,
            layers: layers
        )
    }

    func initLayers(size: CGSize) {
        guard
            size >= MTLRenderer.minimumTextureSize,
            let bottomTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device),
            let topTexture = MTLTextureCreator.makeBlankTexture(size: size, with: device),
            let texture = MTLTextureCreator.makeBlankTexture(size: size, with: device)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.unselectedBottomTexture = bottomTexture
        self.unselectedTopTexture = topTexture

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
    /// Merges the textures of layers into `destinationTexture` with the backgroundColor
    func mergeAllTextures(
        usingCurrentTexture currentTexture: MTLTexture? = nil,
        allLayerUpdates: Bool = false,
        into destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let destinationTexture else { return }

        // Combine the textures of unselected layers into `unselectedTopTexture` and `unselectedBottomTexture`
        // Even if the number of layers increases, performance will not be affected.
        // It is not necessary to update the texture of the unselected layers every time.
        if allLayerUpdates {
            updateUnselectedTexturesIfNeeded(commandBuffer: commandBuffer)
        }

        makeTextureFromUnselectedTextures(
            usingCurrentTexture: currentTexture,
            to: destinationTexture,
            with: commandBuffer
        )
    }

    func updateUnselectedTexturesIfNeeded(
        commandBuffer: MTLCommandBuffer
    ) {
        updateUnselectedBottomTextureIfNeeded(commandBuffer: commandBuffer)
        updateUnselectedTopTextureIfNeeded(commandBuffer: commandBuffer)
    }

    func makeTextureFromUnselectedTextures(
        usingCurrentTexture currentTexture: MTLTexture? = nil,
        to destinationTexture: MTLTexture?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard
            let unselectedBottomTexture,
            let unselectedTopTexture,
            let destinationTexture
        else { return }

        renderer.fillTexture(
            texture: destinationTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: unselectedBottomTexture,
            into: destinationTexture,
            with: commandBuffer
        )

        if layers[index].isVisible, let texture = currentTexture ?? layers[index].texture {
            renderer.mergeTexture(
                texture: texture,
                alpha: layers[index].alpha,
                into: destinationTexture,
                with: commandBuffer
            )
        }

        renderer.mergeTexture(
            texture: unselectedTopTexture,
            into: destinationTexture,
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
        into destinationTexture: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) {
        layers[range]
            .filter { $0.isVisible }
            .compactMap { layer -> (MTLTexture, Int)? in
                guard let texture: MTLTexture = layer.texture else { return nil }
                return (texture, layer.alpha)
            }
            .forEach { result in
                renderer.mergeTexture(
                    texture: result.0,
                    alpha: result.1,
                    into: destinationTexture,
                    with: commandBuffer
                )
            }
    }

    /// Merges the textures of layers below the selected layer into `unselectedBottomTexture`
    private func updateUnselectedBottomTextureIfNeeded(
        commandBuffer: MTLCommandBuffer
    ) {
        guard let unselectedBottomTexture else {
            Logger.standard.error("unselectedBottomTexture is nil")
            return
        }

        renderer.clearTexture(texture: unselectedBottomTexture, with: commandBuffer)

        // The textures of the layers below the selected layer are drawn into `unselectedBottomTexture`
        if index > 0 {
            mergeLayerTextures(range: 0 ... index - 1, into: unselectedBottomTexture, with: commandBuffer)
        }
    }

    /// Merges the textures of layers above the selected layer into `unselectedTopTexture`
    private func updateUnselectedTopTextureIfNeeded(
        commandBuffer: MTLCommandBuffer
    ) {
        guard let unselectedTopTexture else {
            Logger.standard.error("unselectedTopTexture is nil")
            return
        }

        renderer.clearTexture(texture: unselectedTopTexture, with: commandBuffer)

        // The textures of the layers above the selected layer are drawn into `unselectedTopTexture`
        if index < layers.count - 1 {
            mergeLayerTextures(range: index + 1 ... layers.count - 1, into: unselectedTopTexture, with: commandBuffer)
        }
    }

}
