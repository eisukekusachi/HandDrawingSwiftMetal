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
    var textureSize: CGSize { get }

    func initTextures(_ textureSize: CGSize)
    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer)
    func setTexture(_ texture: MTLTexture)
    func makeTexture(fromDocumentsFolder url: URL, textureSize: CGSize) throws -> MTLTexture?

    func clearTexture()

    func clearTexture(_ commandBuffer: MTLCommandBuffer)
}
