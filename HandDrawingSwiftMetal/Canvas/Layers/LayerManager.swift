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
    var textureSize: CGSize = .zero

    var undoObject: UndoObject {
        UndoObject.init(texture: layers[0].texture!)
    }

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initTextures(_ textureSize: CGSize) {
        addLayer(textureSize)
        self.textureSize = textureSize

        clearTextures()
    }

    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer) {
        Command.fill(dstTexture,
                     withRGB: backgroundColor,
                     commandBuffer)

        Command.merge(textures,
                      into: dstTexture,
                      commandBuffer)
    }

    func makeTexture(fromDocumentsFolder url: URL, textureSize: CGSize) throws -> MTLTexture? {
        let textureData: Data? = try Data(contentsOf: url)
        return MTKTextureUtils.makeTexture(device, textureSize, textureData?.encodedHexadecimals)
    }
    func setTexture(_ texture: MTLTexture) {
        layers[0].texture = texture
    }

    func clearTextures() {
        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTextures(commandBuffer)
        commandBuffer.commit()
    }
    func clearTextures(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(texture: layers[0].texture,
                      commandBuffer)
    }
    func updateTextureThumbnail() {
        layers[0].updateThumbnail()
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
        layers.append(layer)
    }
}
