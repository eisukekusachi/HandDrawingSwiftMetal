//
//  UIColorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

extension UIColor {
    
    var rgb: (Int, Int, Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }
    var alpha: Int {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)
        
        return Int(alpha * 255)
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
        
        let rgba = [red, green, blue, alpha].map { i -> CGFloat in
            
            switch i {
            case let i where i < 0:
                return 0
            case let i where i > 255:
                return 1
            default:
                return CGFloat(i) / 255
            }
        }
        self.init(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
    }
}
