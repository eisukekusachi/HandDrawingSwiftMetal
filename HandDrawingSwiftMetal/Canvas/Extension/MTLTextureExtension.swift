//
//  MTLTextureExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import MetalKit
extension MTLTexture {
    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
}
