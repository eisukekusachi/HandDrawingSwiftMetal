//
//  ImageLayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate
import Combine

final class ImageLayerManager: LayerManager<ImageLayerEntity> {

    var refreshCanvasWithMergingDrawingLayersPublisher: AnyPublisher<Void, Never> {
        refreshCanvasWithMergingDrawingLayersSubject.eraseToAnyPublisher()
    }

    var refreshCanvasWithMergingAllLayersPublisher: AnyPublisher<Void, Never> {
        refreshCanvasWithMergingAllLayersSubject.eraseToAnyPublisher()
    }

    var newLayer: ImageLayerEntity {
        .init(
            texture: MTKTextureUtils.makeBlankTexture(device, textureSize),
            title: TimeStampFormatter.current(template: "MMM dd HH mm ss")
        )
    }

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrushLayer.frameSize = frameSize
            drawingEraserLayer.frameSize = frameSize
        }
    }

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

    private let refreshCanvasWithMergingDrawingLayersSubject = PassthroughSubject<Void, Never>()

    private let refreshCanvasWithMergingAllLayersSubject = PassthroughSubject<Void, Never>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initAllLayers(with textureSize: CGSize) {
        self.textureSize = textureSize

        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        drawingBrushLayer.initTextures(textureSize)
        drawingEraserLayer.initTextures(textureSize)

        layers.removeAll()

        super.initLayers(
            index: 0,
            layers: [newLayer]
        )
    }

    func initLayers(undoObject: UndoObject) {
        super.initLayers(
            index: undoObject.index,
            layers: undoObject.layers
        )
    }

}

extension ImageLayerManager {

    func mergeDrawingLayers(
        backgroundColor: UIColor,
        onto dstTexture: MTLTexture,
        to commandBuffer: MTLCommandBuffer
    ) {
        guard
            let selectedTexture = selectedTexture,
            let selectedTextures = drawingLayer?.getDrawingTextures(selectedTexture)
        else { return }

        Command.fill(dstTexture,
                     withRGB: backgroundColor.rgb,
                     commandBuffer)

        Command.merge(texture: bottomTexture,
                      into: dstTexture,
                      commandBuffer)

        if layers[index].isVisible {
            MTKTextureUtils.makeSingleTexture(from: selectedTextures.compactMap { $0 },
                                              to: currentTexture,
                                              commandBuffer)
            Command.merge(texture: currentTexture,
                          alpha: selectedLayer?.alpha ?? 0,
                          into: dstTexture,
                          commandBuffer)
        }

        Command.merge(texture: topTexture,
                      into: dstTexture,
                      commandBuffer)
    }

    func mergeUnselectedLayers(
        to commandBuffer: MTLCommandBuffer
    ) {
        let bottomIndex: Int = index - 1
        let topIndex: Int = index + 1

        Command.clear(texture: bottomTexture, commandBuffer)
        Command.clear(texture: topTexture, commandBuffer)

        if bottomIndex >= 0 {
            for i in 0 ... bottomIndex where layers[i].isVisible {
                Command.merge(
                    texture: layers[i].texture,
                    alpha: layers[i].alpha,
                    into: bottomTexture,
                    commandBuffer)
            }
        }
        if topIndex < layers.count {
            for i in topIndex ..< layers.count where layers[i].isVisible {
                Command.merge(
                    texture: layers[i].texture,
                    alpha: layers[i].alpha,
                    into: topTexture,
                    commandBuffer)
            }
        }
    }

    func refreshCanvasWithMergingDrawingLayers() {
        refreshCanvasWithMergingDrawingLayersSubject.send()
    }

    func refreshCanvasWithMergingAllLayers() {
        refreshCanvasWithMergingAllLayersSubject.send()
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

    func updateSelectedLayerTextureWithNewAddressTexture() {
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
        _ layer: ImageLayerEntity,
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

    func updateTitle(_ layer: ImageLayerEntity, _ title: String) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].title = title
    }

    func updateThumbnail(_ layer: ImageLayerEntity) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
    }

}
