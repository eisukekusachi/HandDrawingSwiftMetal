//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate

enum LayerManagerError: Error {
    case failedToMakeTexture
}
class LayerManager: ObservableObject {
    @Published var layers: [LayerModel] = []
    @Published var index: Int = 0 {
        didSet {
            if index < layers.count {
                selectedLayer = layers[index]
            }
        }
    }
    @Published var selectedLayer: LayerModel?
    @Published var setNeedsDisplay: Bool = false
    @Published var addUndoObject: Bool = false

    @Published var selectedLayerAlpha: Int = 255

    var textureSize: CGSize = .zero
    
    var selectedTexture: MTLTexture? {
        if index < layers.count {
            return layers[index].texture
            
        } else {
            return nil
        }
    }

    private var bottomTexture: MTLTexture!
    private var topTexture: MTLTexture!
    private var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initTextures(_ textureSize: CGSize) {
        bottomTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        topTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)
        currentTexture = MTKTextureUtils.makeBlankTexture(device, textureSize)

        self.textureSize = textureSize

        clearTextures()
    }
    func initLayers(_ textureSize: CGSize) {
        layers.removeAll()
        addLayer(textureSize)
        index = 0
    }
    func merge(drawingTextures: [MTLTexture],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer) {
        Command.fill(dstTexture,
                     withRGB: backgroundColor,
                     commandBuffer)

        Command.merge(texture: bottomTexture,
                      into: dstTexture,
                      commandBuffer)

        if layers[index].isVisible {
            MTKTextureUtils.makeSingleTexture(from: drawingTextures,
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

    func clearTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(commandBuffer)
        commandBuffer.commit()
    }
    func clearTextures(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(texture: layers[index].texture,
                      commandBuffer)
    }

    func updateSelectedLayer(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        index = layerIndex
        selectedLayerAlpha = layer.alpha

        updateNonSelectedTextures()
        setNeedsDisplay = true
    }
    func updateSelectedTexture(_ layer: LayerModel, _ texture: MTLTexture) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].texture = texture
    }
    func updateVisibility(_ layer: LayerModel, _ isVisible: Bool) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].isVisible = isVisible

        updateNonSelectedTextures()
        setNeedsDisplay = true
    }
    func updateLayerAlpha(_ layer: LayerModel, _ alpha: Int) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].alpha = alpha
        setNeedsDisplay = true
    }
    func updateThumbnail(_ layer: LayerModel) {
        guard let layerIndex = layers.firstIndex(of: layer) else { return }
        layers[layerIndex].updateThumbnail()
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
}

extension LayerManager {
    func addLayer(_ textureSize: CGSize) {
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
    func removeLayer() {
        addUndoObject = true

        if layers.count == 1 { return }

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
    func moveLayer(fromOffsets source: IndexSet, toOffset destination: Int) {
        layers = layers.reversed()
        layers.move(fromOffsets: source, toOffset: destination)
        layers = layers.reversed()

        if let selectedLayer,
           let layerIndex = layers.firstIndex(of: selectedLayer) {
            index = layerIndex
            updateNonSelectedTextures()
            setNeedsDisplay = true
        }
    }
}

extension LayerManager {
    var undoObject: UndoObject {
        return UndoObject(index: index, layers: layers)
    }
    func setUndoObject(_ object: UndoObject) {
        index = object.index
        layers = object.layers

        selectedLayerAlpha = layers[index].alpha
    }
}

extension LayerManager {
    static func convertLayerModelCodableArray(layers: [LayerModel],
                                              fileIO: FileIO,
                                              folderURL: URL) async throws -> [LayerModelCodable] {
        var resultLayers: [LayerModelCodable] = []

        let tasks = layers.map { layer in
            Task<LayerModelCodable?, Error> {
                do {
                    if let texture = layer.texture {
                        let textureName = UUID().uuidString

                        try fileIO.saveImage(bytes: texture.bytes,
                                             to: folderURL.appendingPathComponent(textureName))

                        return LayerModelCodable.init(textureName: textureName,
                                                      title: layer.title,
                                                      isVisible: layer.isVisible,
                                                      alpha: layer.alpha)
                    } else {
                        return nil
                    }

                } catch {
                    return nil
                }
            }
        }

        for task in tasks {
            if let fileURL = try? await task.value {
                resultLayers.append(fileURL)
            }
        }

        return resultLayers.compactMap { $0 }
    }
}
