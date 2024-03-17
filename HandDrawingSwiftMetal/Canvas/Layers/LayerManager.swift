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

    @Published var setNeedsDisplay: Bool = false
    @Published var addUndoObject: Bool = false

    var frameSize: CGSize = .zero {
        didSet {
            drawingBrush.frameSize = frameSize
            drawingEraser.frameSize = frameSize
        }
    }

    /// Drawing with a brush
    let drawingBrush = DrawingBrush()

    /// Drawing with an eraser
    let drawingEraser = DrawingEraser()

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

    var selectedTexture: MTLTexture? {
        guard index < layers.count else { return nil }
        return layers[index].texture
    }

    var arrowPointX: CGFloat = 0.0

    private var textureSize: CGSize = .zero

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initLayerManager(_ textureSize: CGSize) {
        self.textureSize = textureSize

        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        drawingBrush.initTextures(textureSize)
        drawingEraser.initTextures(textureSize)
        
        layers.removeAll()
        index = 0
        
        addLayer()
    }

    func mergeAllTextures(selectedTextures: [MTLTexture],
                          selectedAlpha: Int,
                          backgroundColor: (Int, Int, Int),
                          to dstTexture: MTLTexture,
                          _ commandBuffer: MTLCommandBuffer) {
        Command.fill(dstTexture,
                     withRGB: backgroundColor,
                     commandBuffer)

        Command.merge(texture: bottomTexture,
                      into: dstTexture,
                      commandBuffer)

        if layers[index].isVisible {
            MTKTextureUtils.makeSingleTexture(from: selectedTextures,
                                              to: currentTexture,
                                              commandBuffer)
            Command.merge(texture: currentTexture,
                          alpha: selectedAlpha,
                          into: dstTexture,
                          commandBuffer)
        }

        Command.merge(texture: topTexture,
                      into: dstTexture,
                      commandBuffer)
    }
}

// CRUD
extension LayerManager {
    func addLayer() {
        addUndoObject = true
        
        let title = TimeStampFormatter.current(template: "MMM dd HH mm ss")
        let texture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        let layer = LayerModel(texture: texture,
                               title: title)

        if index < layers.count - 1 {
            layers.insert(layer, at: index + 1)
        } else {
            layers.append(layer)
        }

        updateNonSelectedTextures()
    }
    func moveLayer(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let tmpSelectedLayer = selectedLayer else { return }

        layers = layers.reversed()
        layers.move(fromOffsets: source, toOffset: destination)
        layers = layers.reversed()

        if let layerIndex = layers.firstIndex(of: tmpSelectedLayer) {
            index = layerIndex
            updateNonSelectedTextures()
            setNeedsDisplay = true
        }
    }
    func removeLayer() {
        if layers.count == 1 { return }

        addUndoObject = true

        layers.remove(at: index)

        // Updates the value for UI update
        var curretnIndex = index
        if curretnIndex > layers.count - 1 {
            curretnIndex = layers.count - 1
        }
        index = curretnIndex

        updateNonSelectedTextures()
        setNeedsDisplay = true
    }

    func updateNonSelectedTextures() {
        let bottomIndex: Int = index - 1
        let topIndex: Int = index + 1

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!

        Command.clear(texture: bottomTexture, commandBuffer)
        Command.clear(texture: topTexture, commandBuffer)

        if bottomIndex >= 0 {
            for i in 0 ... bottomIndex where layers[i].isVisible {
                Command.merge(texture: layers[i].texture,
                              alpha: layers[i].alpha,
                              into: bottomTexture,
                              commandBuffer)
            }
        }
        if topIndex < layers.count {
            for i in topIndex ..< layers.count where layers[i].isVisible {
                Command.merge(texture: layers[i].texture,
                              alpha: layers[i].alpha,
                              into: topTexture,
                              commandBuffer)
            }
        }

        commandBuffer.commit()
    }
    func updateLayer(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
        updateNonSelectedTextures()
        setNeedsDisplay = true
    }
    func updateLayerAlpha(_ layer: LayerModel, _ alpha: Int) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].alpha = alpha
        setNeedsDisplay = true
    }
    func updateTexture(_ layer: LayerModel, _ texture: MTLTexture) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].texture = texture
    }
    func updateTitle(_ layer: LayerModel, _ title: String) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].title = title
    }
    func updateThumbnail(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
    }
    func updateVisibility(_ layer: LayerModel, _ isVisible: Bool) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].isVisible = isVisible
        updateNonSelectedTextures()
        setNeedsDisplay = true
    }
}
