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

    @Published var selectedTextureAlpha: Int = 255

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
        newLayer(textureSize)

        bottomTexture = MTKTextureUtils.makeTexture(device, textureSize)!
        topTexture = MTKTextureUtils.makeTexture(device, textureSize)!
        currentTexture = MTKTextureUtils.makeTexture(device, textureSize)!

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!

        Command.clear(texture: bottomTexture, commandBuffer)
        Command.clear(texture: topTexture, commandBuffer)
        Command.clear(texture: currentTexture, commandBuffer)

        commandBuffer.commit()

        self.textureSize = textureSize
        self.index = 0

        clearTextures()
    }
    func newLayer(_ textureSize: CGSize) {
        layers.removeAll()
        addLayer(textureSize)
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
                          alpha: selectedTextureAlpha,
                          into: dstTexture,
                          commandBuffer)
        }

        Command.merge(texture: topTexture,
                      into: dstTexture,
                      commandBuffer)
    }

    func setTexture(_ texture: MTLTexture) {
        layers[index].texture = texture
    }
    func setVisibility(_ layer: LayerModel, _ isVisible: Bool) {
        if let index = layers.firstIndex(of: layer) {
            layers[index].isVisible = isVisible
        }
    }

    func isSelected(_ layer: LayerModel) -> Bool {
        guard let selectedLayer else { return false }
        return layer.id == selectedLayer.id
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

    func setSelectedIndex(_ index: Int) {
        if index < layers.count {
            self.index = index
        }
    }

    func updateSelectedIndex() {
        if  let selectedLayer,
            let resultIndex = layers.firstIndex(of: selectedLayer) {
            index = resultIndex
        } else {
            index = 0
        }
    }
    func updateTextureThumbnail() {
        layers[index].updateThumbnail()
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
    func updateSelectedTextureAlpha() {
        selectedTextureAlpha = layers[index].alpha
    }
    func updateTextureAlpha(_ alpha: Int) {
        layers[index].alpha = alpha
    }
}

extension LayerManager {
    func addLayer(_ textureSize: CGSize) {
        let title = TimeStampFormatter.current(template: "MMM dd HH mm ss")
        let texture = MTKTextureUtils.makeTexture(device, textureSize)!

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        Command.clear(texture: texture,
                      commandBuffer)
        commandBuffer.commit()

        let layer = LayerModel(texture: texture,
                               title: title)

        if index < layers.count - 1 {
            layers.insert(layer, at: index + 1)
        } else {
            layers.append(layer)
        }
    }
    func removeLayer() {
        if layers.count == 1 { return }

        layers.remove(at: index)

        // Updates the value for UI update
        var curretnIndex = index
        if curretnIndex > layers.count - 1 {
            curretnIndex = layers.count - 1
        }
        index = curretnIndex
    }
    func moveLayer(fromOffsets source: IndexSet, toOffset destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        updateNonSelectedTextures()
    }
}

extension LayerManager {
    var undoObject: UndoObject {
        return UndoObject(index: index, layers: layers)
    }
    func setUndoObject(_ object: UndoObject) {
        index = object.index
        layers = object.layers

        selectedTextureAlpha = layers[index].alpha
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
