//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

class LayerManager: LayerManagerProtocol {

    var canvas: Canvas!

    private (set) var currentTexture: MTLTexture!

    private var textureSize: CGSize = .zero

    required init(canvas: Canvas) {
        self.canvas = canvas
    }
    func initializeTextures(textureSize: CGSize) {
        assert(canvas.device != nil, "Device is nil.")

        if self.textureSize != textureSize {
            self.textureSize = textureSize
            self.currentTexture = canvas.device!.makeTexture(textureSize)
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
        Command.clear(texture: currentTexture,
                      canvas.commandBuffer)
    }
}
