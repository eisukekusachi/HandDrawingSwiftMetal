//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate
import Combine

enum LayerManagerError: Error {
    case failedToMakeTexture
}

class LayerManager: ObservableObject {

    @Published var selectedLayer: LayerModel?
    @Published var selectedLayerAlpha: Int = 255

    var refreshCanvasWithMergingDrawingLayersPublisher: AnyPublisher<Void, Never> {
        refreshCanvasWithMergingDrawingLayersSubject.eraseToAnyPublisher()
    }

    var refreshCanvasWithMergingAllLayersPublisher: AnyPublisher<Void, Never> {
        refreshCanvasWithMergingAllLayersSubject.eraseToAnyPublisher()
    }

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrushLayer.frameSize = frameSize
            drawingEraserLayer.frameSize = frameSize
        }
    }

    var layers: [LayerModel] = [] {
        didSet {
            guard index < layers.count else { return }
            selectedLayer = layers[index]
            selectedLayerAlpha = layers[index].alpha
        }
    }
    var index: Int = 0 {
        didSet {
            guard index < layers.count else { return }
            selectedLayer = layers[index]
            selectedLayerAlpha = layers[index].alpha
        }
    }

    var arrowPointX: CGFloat = 0.0

    /// A protocol for managing current drawing layer
    private (set) var drawingLayer: DrawingLayer?
    /// Drawing with a brush
    private let drawingBrushLayer = DrawingBrushLayer()
    /// Drawing with an eraser
    private let drawingEraserLayer = DrawingEraserLayer()

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private var textureSize: CGSize = .zero

    private let refreshCanvasWithMergingDrawingLayersSubject = PassthroughSubject<Void, Never>()

    private let refreshCanvasWithMergingAllLayersSubject = PassthroughSubject<Void, Never>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initLayers(with textureSize: CGSize) {
        self.textureSize = textureSize

        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        drawingBrushLayer.initTextures(textureSize)
        drawingEraserLayer.initTextures(textureSize)

        self.layers.removeAll()

        self.addLayer()
        self.index = 0
    }

    func initLayers(with newTexture: MTLTexture) {
        self.layers.removeAll()

        let layerData = LayerModel.init(
            texture: newTexture,
            title: "NewLayer"
        )
        self.layers.append(layerData)
        self.index = 0
    }

    func initLayers(index: Int, layers: [LayerModel]) {
        self.layers = layers
        self.index = index
    }

    func initLayers(undoObject: UndoObject) {
        self.index = undoObject.index
        self.layers = undoObject.layers
    }

    func setDrawingLayer(_ tool: DrawingToolType) {
        drawingLayer = tool == .eraser ? drawingEraserLayer : drawingBrushLayer
    }

}

extension LayerManager {

    func addMergeDrawingLayersCommands(
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
                          alpha: selectedLayerAlpha,
                          into: dstTexture,
                          commandBuffer)
        }

        Command.merge(texture: topTexture,
                      into: dstTexture,
                      commandBuffer)
    }

    func addMergeUnselectedLayersCommands(
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

// CRUD
extension LayerManager {
   
    func addLayer() {
        let title = TimeStampFormatter.current(template: "MMM dd HH mm ss")
        let texture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        let layer = LayerModel(
            texture: texture,
            title: title
        )

        if index < layers.count - 1 {
            layers.insert(layer, at: index + 1)
        } else {
            layers.append(layer)
        }
    }

    func moveLayer(
        fromOffsets source: IndexSet,
        toOffset destination: Int,
        selectedLayer: LayerModel
    ) {
        layers = layers.reversed()
        layers.move(fromOffsets: source, toOffset: destination)
        layers = layers.reversed()

        if let layerIndex = layers.firstIndex(of: selectedLayer) {
            index = layerIndex
        }
    }

    func removeLayer() {
        layers.remove(at: index)

        // Updates the value for UI update
        var currentIndex = index
        if currentIndex > layers.count - 1 {
            currentIndex = layers.count - 1
        }
        index = currentIndex
    }

    func updateLayer(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
    }

    func updateTitle(_ layer: LayerModel, _ title: String) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].title = title
    }

    func updateVisibility(_ layer: LayerModel, _ isVisible: Bool) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].isVisible = isVisible
    }

    func updateAlpha(_ layer: LayerModel, _ alpha: Int) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].alpha = alpha
    }

    func updateThumbnail(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
    }

}

extension LayerManager {

    var selectedTexture: MTLTexture? {
        guard index < layers.count else { return nil }
        return layers[index].texture
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

    func clearDrawingLayer() {
        drawingLayer?.clearDrawingTextures()
    }

}
