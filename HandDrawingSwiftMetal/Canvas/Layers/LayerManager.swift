//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

class LayerManager: LayerManagerProtocol {

    private (set) var currentTexture: MTLTexture!

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    private var textureSize: CGSize = .zero

    func initTextures(_ textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize
            self.currentTexture = device.makeTexture(textureSize)
        }

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

    func setTexture(_ texture: MTLTexture) {
        currentTexture = texture
    }

    func clearTexture(_ commandBuffer: MTLCommandBuffer) {
        Command.clear(texture: currentTexture,
                      commandBuffer)
    }
}
