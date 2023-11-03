//
//  LayerManagerProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/09.
//

import MetalKit

protocol LayerManagerProtocol {

    var currentTexture: MTLTexture! { get }

    func initializeTextures(textureSize: CGSize)

    func mergeAllTextures(currentTextures: [MTLTexture?],
                          backgroundColor: (Int, Int, Int),
                          to dstTexture: MTLTexture)
    func clearTexture()
}
