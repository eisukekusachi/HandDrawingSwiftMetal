//
//  ImageLayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate
import Combine

final class ImageLayerManager: LayerManager<ImageLayerCellItem> {

    var frameSize: CGSize = .zero

    /// A protocol for managing current drawing layer
    private (set) var drawingLayer: DrawingLayer?
    /// Drawing with a brush
    private let drawingBrushLayer = DrawingBrushLayer()
    /// Drawing with an eraser
    private let drawingEraserLayer = DrawingEraserLayer()

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private (set) var textureSize: CGSize = .zero

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initialize(
        textureSize: CGSize,
        layerIndex: Int = 0,
        layers: [ImageLayerCellItem] = []
    ) {
        initializeProperties(textureSize: textureSize)

        var layers = layers
        if layers.isEmpty {
            layers.append(
                makeNewLayer(textureSize: textureSize)
            )
        }

        super.initLayers(
            index: layerIndex,
            layers: layers
        )
    }

    private func initializeProperties(textureSize: CGSize) {

        self.textureSize = textureSize

        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        drawingBrushLayer.initTextures(textureSize)
        drawingEraserLayer.initTextures(textureSize)

        layers.removeAll()
    }

    private func makeNewLayer(textureSize: CGSize) -> ImageLayerCellItem {
        .init(
            texture: MTKTextureUtils.makeBlankTexture(device, textureSize),
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
    }

}

extension ImageLayerManager {

    func addNewLayer() {
        let newLayer = makeNewLayer(textureSize: textureSize)
        addLayer(newLayer)
    }

    func drawAllLayers(
        backgroundColor: UIColor,
        onto destinationTexture: MTLTexture?,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let destinationTexture,
            let selectedTexture = selectedTexture,
            let selectedTextures = drawingLayer?.getDrawingTextures(selectedTexture)
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

    func mergeAllLayers(
        backgroundColor: UIColor,
        onto destinationTexture: MTLTexture,
        _ commandBuffer: MTLCommandBuffer
    ) {
        guard
            let selectedTexture = selectedTexture,
            let selectedTextures = drawingLayer?.getDrawingTextures(selectedTexture)
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

}

extension ImageLayerManager {

    var selectedTexture: MTLTexture? {
        guard index < layers.count else { return nil }
        return layers[index].texture
    }

    func setDrawingLayer(_ tool: DrawingToolType) {
        drawingLayer = tool == .eraser ? drawingEraserLayer : drawingBrushLayer
    }

    func clearDrawingLayer() {
        drawingLayer?.clearDrawingTextures()
    }

    func updateTextureAddress() {
        guard
            let device: MTLDevice = MTLCreateSystemDefaultDevice(),
            let selectedTexture = selectedTexture,
            let newTexture = MTKTextureUtils.duplicateTexture(device, selectedTexture)
        else { return }

        layers[index].texture = newTexture
    }

    @MainActor
    func updateCurrentThumbnail() async throws {
        try await Task.sleep(nanoseconds: 1 * 1000 * 1000)
        if let selectedLayer {
            updateThumbnail(selectedLayer)
        }
    }

    func update(
        _ layer: ImageLayerCellItem,
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

    func updateTitle(_ layer: ImageLayerCellItem, _ title: String) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].title = title
    }

    func updateThumbnail(_ layer: ImageLayerCellItem) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
    }

}
