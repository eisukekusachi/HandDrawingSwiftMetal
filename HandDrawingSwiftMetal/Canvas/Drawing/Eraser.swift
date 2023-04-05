//
//  Eraser.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import Foundation

struct Eraser {
    
    static let minDiameter: Int = 1
    static let maxDiameter: Int = 64
    
    var alpha: Int = 200
    var diameter: Int = 8
    var blurSize: Float = initBlurSize
    
    var blurredSize: BlurredSize {
        return BlurredSize(diameter: diameter, blurSize: blurSize)
    }
    
    mutating func setValue(alpha: Int? = nil, diameter: Int? = nil) {
        if let alpha = alpha {
            self.alpha = alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
}
