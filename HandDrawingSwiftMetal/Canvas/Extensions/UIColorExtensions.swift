//
//  UIColorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

extension UIColor {

    var alpha: Int {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)

        return Int(alpha * 255)
    }

    var rgb: (Int, Int, Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)

        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    var rgba: (Int, Int, Int, Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
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

    convenience init(rgb: (Int, Int, Int)) {
        let red: Int = max(0, min(rgb.0, 255))
        let green: Int = max(0, min(rgb.1, 255))
        let blue: Int = max(0, min(rgb.2, 255))

        self.init(
            red: (CGFloat(red) / 255.0),
            green: (CGFloat(green) / 255.0),
            blue: (CGFloat(blue) / 255.0),
            alpha: 1.0
        )
    }

    convenience init(rgba: (Int, Int, Int, Int)) {
        let red: Int = max(0, min(rgba.0, 255))
        let green: Int = max(0, min(rgba.1, 255))
        let blue: Int = max(0, min(rgba.2, 255))
        let alpha: Int = max(0, min(rgba.3, 255))

        self.init(
            red: (CGFloat(red) / 255.0),
            green: (CGFloat(green) / 255.0),
            blue: (CGFloat(blue) / 255.0),
            alpha: (CGFloat(alpha) / 255.0)
        )
    }

}
