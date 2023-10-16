//
//  Brush.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

let initBrushSize: Int = 8

class Brush {
    var rgb: (Int, Int, Int) = (0, 0, 0)
    var alpha: Int = 200

    var diameter: Int = initBrushSize
    var blurSize: Float = initBlurSize

    var blurredDotSize: BlurredDotSize {
        return BlurredDotSize(diameter: diameter, blurSize: blurSize)
    }

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

    var color: UIColor {
        return UIColor(red: CGFloat(rgb.0) / 255.0,
                       green: CGFloat(rgb.1) / 255.0,
                       blue: CGFloat(rgb.1) / 255.0,
                       alpha: CGFloat(alpha) / 255.0)
    }

    func setR(_ value: Int) {
        rgb = (value, rgb.1, rgb.2)
    }
    func setG(_ value: Int) {
        rgb = (rgb.0, value, rgb.2)
    }
    func setB(_ value: Int) {
        rgb = (rgb.0, rgb.1, value)
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

extension Brush {
    static let minDiameter: Int = 1
    static let maxDiameter: Int = 64

    static func diameterIntValue(_ value: Float) -> Int {
        Int(value * Float(maxDiameter - minDiameter)) + minDiameter
    }
    static func diameterFloatValue(_ value: Int) -> Float {
        Float(value - minDiameter) / Float(maxDiameter - minDiameter)
    }
}
