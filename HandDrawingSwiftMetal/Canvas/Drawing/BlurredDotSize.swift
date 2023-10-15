//
//  BlurredDotSize.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

let initBlurSize: Float = 4.0

struct BlurredDotSize {
    var diameter: Int
    var blurSize: Float
    var totalSize: Float {
        return Float(diameter) + blurSize * 2
    }
}
