//
//  TextureLayerUndoObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/03.
//

import Foundation
import MetalKit

struct TextureLayerUndoObject {

    let textureSize: CGSize

    let index: Int
    let layers: [TextureLayer]

    let topTexture: MTLTexture?
    let bottomTexture: MTLTexture?
}

extension TextureLayers {

    func getUndoObject(
        device: MTLDevice?
    ) -> TextureLayerUndoObject? {

        var layers = layers
        let currentLayer = layers[index]

        var currentTopTexture: MTLTexture? = nil
        var currentBottomTexture: MTLTexture? = nil

        guard
            let device,
            let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
            let duplicateCurrentLayerTexture = MTLTextureCreator.duplicateTexture(
                texture: currentLayer.texture,
                withDevice: device,
                withCommandBuffer: commandBuffer
            )
        else { return nil }

        if let topTexture {
            currentTopTexture = MTLTextureCreator.duplicateTexture(
                texture: topTexture,
                withDevice: device,
                withCommandBuffer: commandBuffer
            )
        }
        if let bottomTexture {
            currentBottomTexture = MTLTextureCreator.duplicateTexture(
                texture: bottomTexture,
                withDevice: device,
                withCommandBuffer: commandBuffer
            )
        }
        commandBuffer.commit()

        layers[index] = .init(
            texture: duplicateCurrentLayerTexture,
            title: currentLayer.title,
            thumbnail: currentLayer.thumbnail,
            alpha: currentLayer.alpha,
            isVisible: currentLayer.isVisible
        )

        return .init(
            textureSize: duplicateCurrentLayerTexture.size,
            index: index,
            layers: layers,
            topTexture: currentTopTexture,
            bottomTexture: currentBottomTexture
        )
    }

}
