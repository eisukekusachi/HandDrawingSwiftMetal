//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate

protocol LayerManager {
    var currentTexture: MTLTexture! { get }

    func initTextures(_ textureSize: CGSize)
    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer)
    func setTexture(_ texture: MTLTexture)
    func setTexture(url: URL, textureSize: CGSize) throws
    func clearTexture(_ commandBuffer: MTLCommandBuffer)
}
