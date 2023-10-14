//
//  MTLTextureExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit

extension MTLTexture {
    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
}
