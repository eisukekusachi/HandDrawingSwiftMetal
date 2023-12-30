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
    var textureSize: CGSize = .zero

    private (set) var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    func initTextures(_ textureSize: CGSize) {
        self.textureSize = textureSize
        self.currentTexture = MTKTextureUtils.makeTexture(device, textureSize)

        let commandBuffer = device.makeCommandQueue()!.makeCommandBuffer()!
        clearTexture(commandBuffer)
        commandBuffer.commit()
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
        currentTexture = texture
    }

    func clearTexture(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(texture: currentTexture,
                      commandBuffer)
    }
}
