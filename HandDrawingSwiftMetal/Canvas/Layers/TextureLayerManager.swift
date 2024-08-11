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

    /// A protocol for managing current drawing texture layer
    private (set) var drawingTextureLayer: DrawingTextureLayer?
    /// A drawing texture layer with a brush
    private let brushDrawingTextureLayer = BrushDrawingTextureLayer()
    /// A drawing texture layer with an eraser
    private let eraserDrawingTextureLayer = EraserDrawingTextureLayer()

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

}

extension TextureLayerManager {

    func reset(
        newLayers: [TextureLayer] = [],
        layerIndex: Int = 0,
        textureSize: CGSize
    ) {
        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        brushDrawingTextureLayer.initTexture(textureSize)
        eraserDrawingTextureLayer.initTexture(textureSize)

        layers.removeAll()

        var newLayers = newLayers
        if newLayers.isEmpty {
            newLayers.append(
                makeNewLayer(textureSize: textureSize)
            )
        }

        super.initLayers(
            index: layerIndex,
            layers: newLayers
        )
    }

    func addNewLayer(textureSize: CGSize) {
        let newLayer = makeNewLayer(textureSize: textureSize)
        addLayer(newLayer)
    }

    func mergeAllLayers(
        backgroundColor: UIColor,
        onto destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let destinationTexture,
            let selectedTexture = selectedTexture,
            let selectedTextures = drawingTextureLayer?.getDrawingTexture(includingSelectedTexture: selectedTexture)
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
            MTLRenderer.draw(
                textures: selectedTextures.compactMap { $0 },
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

}

extension TextureLayerManager {

    var selectedTexture: MTLTexture? {
        guard index < layers.count else { return nil }
        return layers[index].texture
    }

    func setDrawingLayer(_ tool: DrawingToolType) {
        drawingTextureLayer = tool == .eraser ? eraserDrawingTextureLayer : brushDrawingTextureLayer
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

    func update(
        _ layer: TextureLayer,
        isVisible: Bool? = nil,
        alpha: Int? = nil
    ) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        if let isVisible {
            layers[layerIndex].isVisible = isVisible
        }

        if let alpha {
            layers[layerIndex].alpha = alpha
        }
    }

    @MainActor
    func updateCurrentThumbnail() async throws {
        try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
        if let selectedLayer {
            updateThumbnail(selectedLayer)
        }
    }

    func updateTitle(_ layer: TextureLayer, _ title: String) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].title = title
    }

    func updateThumbnail(_ layer: TextureLayer) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
    }

    func updateTextureAddress() {
        guard
            let device: MTLDevice = MTLCreateSystemDefaultDevice(),
            let selectedTexture = selectedTexture,
            let newTexture = MTKTextureUtils.duplicateTexture(device, selectedTexture)
        else { return }

        layers[index].texture = newTexture
    }

}

extension TextureLayerManager {

    private func makeNewLayer(textureSize: CGSize) -> TextureLayer {
        .init(
            texture: MTKTextureUtils.makeBlankTexture(device, textureSize),
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
    }

}
