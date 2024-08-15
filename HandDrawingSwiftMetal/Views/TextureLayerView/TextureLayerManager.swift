//
//  TextureLayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate
import Combine

final class TextureLayerManager: LayerManager<TextureLayer> {

    var selectedTexture: MTLTexture? {
        guard index < layers.count else { return nil }
        return layers[index].texture
    }

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

}

extension TextureLayerManager {

    func drawAllTextures(
        drawingTextureLayer: DrawingTextureLayer? = nil,
        backgroundColor: UIColor,
        onto destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let selectedTexture,
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
            // Merge the `selectedTexture` into the `currentTexture` if there is something currently being drawn, including it in the process
            let selectedTextures = drawingTextureLayer?.getDrawingTexture( includingSelectedTexture: selectedTexture) ?? [selectedTexture]
            MTLRenderer.drawTextures(
                selectedTextures.compactMap { $0 },
                on: currentTexture,
                commandBuffer
            )

            MTLRenderer.merge(
                texture: currentTexture,
                alpha: selectedLayer?.alpha ?? 0,
                into: destinationTexture,
                commandBuffer
            )
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
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

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

    func getIndex(layer: TextureLayer) -> Int? {
        layers.firstIndex(of: layer)
    }

}

extension TextureLayerManager {

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

    func updateTextureAddress() {
        guard
            let selectedTexture = selectedTexture,
            let newTexture = MTKTextureUtils.duplicateTexture(device, selectedTexture)
        else { return }

        layers[index].texture = newTexture
    }

}
