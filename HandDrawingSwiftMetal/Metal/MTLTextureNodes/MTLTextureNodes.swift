//
//  MTLTextureNodes.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/11/07.
//

import Foundation

struct MTLTextureNodes {
    var vertices: MTLTextureVertices = MTLTextureVertices()
    var textureCoord: MTLTextureCoordinates = .screenTextureCoordinates
    var indices: MTLTextureIndices = MTLTextureIndices()
}

extension MTLTextureNodes {

    static let textureNodes: MTLTextureNodes = .init()

    static let flippedTextureNodes: MTLTextureNodes = .init(
        vertices: MTLTextureVertices(),
        textureCoord: .cartesianTextureCoordinates,
        indices: MTLTextureIndices()
    )

}
