//
//  CanvasBrushDrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

class CanvasBrushDrawingTool: CanvasDrawingTool {
    var color: UIColor {
        UIColor(red: CGFloat(rgb.0) / 255.0,
                green: CGFloat(rgb.1) / 255.0,
                blue: CGFloat(rgb.1) / 255.0,
                alpha: CGFloat(alpha) / 255.0)
    }
    var diameter: Int = initBrushSize

    var blurredDotSize: BlurredDotSize {
        BlurredDotSize(diameter: Float(diameter), blurSize: blurSize)
    }

    private(set) var rgb: (Int, Int, Int) = (0, 0, 0)
    private(set) var alpha: Int = 255

    private var blurSize: Float = BlurredDotSize.initBlurSize

    init(color: UIColor?, diameter: Int? = nil) {
        if let color = color {
            rgb = color.rgb
            alpha = color.alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
    init(rgb: (Int, Int, Int)? = nil, alpha: Int? = nil, diameter: Int? = nil) {
        if let rgb = rgb {
            self.rgb = rgb
        }
        if let alpha = alpha {
            self.alpha = alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }

    func setValue(color: UIColor? = nil, diameter: Int? = nil) {
        if let color = color {
            rgb = color.rgb
            alpha = color.alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
    func setValue(rgba: (Int, Int, Int, Int)? = nil, diameter: Int? = nil) {
        if let rgba = rgba {
            self.rgb = (rgba.0, rgba.1, rgba.2)
            self.alpha = rgba.3
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
    func setValue(rgb: (Int, Int, Int)? = nil, alpha: Int? = nil, diameter: Int? = nil) {
        if let rgb = rgb {
            self.rgb = rgb
        }
        if let alpha = alpha {
            self.alpha = alpha
        }
        if let diameter = diameter {
            self.diameter = diameter
        }
    }
}

extension CanvasBrushDrawingTool {
    static let minDiameter: Int = 1
    static let maxDiameter: Int = 64

    static let initBrushSize: Int = 8

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
