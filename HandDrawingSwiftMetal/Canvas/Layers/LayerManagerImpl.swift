//
//  LayerManagerImpl.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate

enum LayerManagerError: Error {
    case failedToMakeTexture
}
class LayerManagerImpl: LayerManager {
    @Published var layers: [LayerModel] = []
    var textureSize: CGSize = .zero

    var undoObject: UndoObject {
        UndoObject.init(texture: layers[0].texture!)
    }

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initTextures(_ textureSize: CGSize) {
        let layer = LayerModel(texture: MTKTextureUtils.makeTexture(device, textureSize))
        layers.append(layer)

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
}
