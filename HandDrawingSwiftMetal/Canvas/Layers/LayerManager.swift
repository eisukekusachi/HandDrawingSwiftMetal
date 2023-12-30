//
//  LayerManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/16.
//

import MetalKit
import Accelerate

protocol LayerManager {
    var layers: [LayerModel] { get set }
    var textureSize: CGSize { get }
    var undoObject: UndoObject { get }

    func initTextures(_ textureSize: CGSize)
    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer)
    func setTexture(_ texture: MTLTexture)
    func makeTexture(fromDocumentsFolder url: URL, textureSize: CGSize) throws -> MTLTexture?

    func clearTextures()

    func clearTextures(_ commandBuffer: MTLCommandBuffer)
}
