//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

class LayerManager: LayerManagerProtocol {

    var canvas: Canvas!

    var currentTexture: MTLTexture {
        return texture
    }

    var texture: MTLTexture!

    private var textureSize: CGSize = .zero

    required init(canvas: Canvas) {
        self.canvas = canvas
    }
    func initializeTextures(textureSize: CGSize) {
        if self.textureSize != textureSize {
            self.textureSize = textureSize

            self.texture = canvas.device!.makeTexture(textureSize)
        }

        clearTexture()
    }
    func mergeAllTextures(currentTextures: [MTLTexture?], backgroundColor: (Int, Int, Int), to displayTexture: MTLTexture) {
        Command.fill(displayTexture,
                     withRGB: backgroundColor,
                     canvas.commandBuffer)

        Command.merge(dst: displayTexture,
                      textures: currentTextures,
                      canvas.commandBuffer)
    }

    func clearTexture() {
        Command.clear(texture: texture,
                      canvas.commandBuffer)
    }
}
