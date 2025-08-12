//
//  UIColorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

public extension UIColor {

    var alpha: Int {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)

        return Int(alpha * 255)
    }

    var rgb: IntRGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)

        return .init(Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    var rgba: IntRGBA {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return .init(Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
    }

    func hexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<24 | (Int)(g*255)<<16 | (Int)(b*255)<<8 | (Int)(a*255)<<0
        return String(format:"#%08x", rgb)
    }

    convenience init(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Int = 255) {
        let red: Int = max(0, min(red, 255))
        let green: Int = max(0, min(green, 255))
        let blue: Int = max(0, min(blue, 255))
        let alpha: Int = max(0, min(alpha, 255))

        self.init(
            red: (CGFloat(red) / 255.0),
            green: (CGFloat(green) / 255.0),
            blue: (CGFloat(blue) / 255.0),
            alpha: (CGFloat(alpha) / 255.0)
        )
    }

    convenience init(rgb: IntRGB) {
        let red: Int = max(0, min(rgb.r, 255))
        let green: Int = max(0, min(rgb.g, 255))
        let blue: Int = max(0, min(rgb.b, 255))

        self.init(
            red: (CGFloat(red) / 255.0),
            green: (CGFloat(green) / 255.0),
            blue: (CGFloat(blue) / 255.0),
            alpha: 1.0
        )
    }

    convenience init(rgba: IntRGBA) {
        let red: Int = max(0, min(rgba.r, 255))
        let green: Int = max(0, min(rgba.g, 255))
        let blue: Int = max(0, min(rgba.b, 255))
        let alpha: Int = max(0, min(rgba.a, 255))

        self.init(
            red: (CGFloat(red) / 255.0),
            green: (CGFloat(green) / 255.0),
            blue: (CGFloat(blue) / 255.0),
            alpha: (CGFloat(alpha) / 255.0)
        )
    }

    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF000000) >> 24) / 255
        let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255
        let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255
        let a = CGFloat(rgb & 0x000000FF) / 255

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
