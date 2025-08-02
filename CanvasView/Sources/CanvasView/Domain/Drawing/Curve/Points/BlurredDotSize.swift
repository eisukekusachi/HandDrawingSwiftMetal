//
//  BlurredDotSize.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

struct BlurredDotSize {
    var diameter: Float
    var blurSize: Float = BlurredDotSize.initBlurSize
}

extension BlurredDotSize {

    static let initBlurSize: Float = 4.0

    var diameterIncludingBlurSize: Float {
        return diameter + blurSize * 2
    }

}
