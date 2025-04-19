//
//  CanvasEraserDrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import Foundation

class CanvasEraserDrawingTool: CanvasDrawingTool {
    var diameter: Int = initEraserSize

    private(set) var alpha: Int = 255

    private var blurSize: Float = BlurredDotSize.initBlurSize

    var blurredDotSize: BlurredDotSize {
        BlurredDotSize(diameter: Float(diameter), blurSize: blurSize)
    }

    func setValue(alpha: Int? = nil, diameter: Int? = nil) {
        if let alpha = alpha {
            self.alpha = alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
}

extension CanvasEraserDrawingTool {
    static let minDiameter: Int = 1
    static let maxDiameter: Int = 64

    static let initEraserSize: Int = 8

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
