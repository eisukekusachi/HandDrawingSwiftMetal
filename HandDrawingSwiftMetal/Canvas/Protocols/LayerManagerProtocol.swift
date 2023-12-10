//
//  LayerManagerProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

protocol LayerManagerProtocol {

    var currentTexture: MTLTexture! { get }

    func initTextures(_ textureSize: CGSize)
    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer)
    func setTexture(_ texture: MTLTexture)
    func clearTexture(_ commandBuffer: MTLCommandBuffer)
}
