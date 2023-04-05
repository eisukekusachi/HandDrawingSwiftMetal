//
//  UIColorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/28.
//

import UIKit

extension UIColor {
    
    var rgb: (Int, Int, Int) {
        guard let components = self.cgColor.components, components.count == 4 else { return (255, 255, 255) }
        return (Int(components[0] * 255),
                Int(components[1] * 255),
                Int(components[2] * 255))
    }
    var rgba: (Int, Int, Int, Int) {
        guard let components = self.cgColor.components, components.count == 4 else { return (255, 255, 255, 255) }
        return (Int(components[0] * 255),
                Int(components[1] * 255),
                Int(components[2] * 255),
                Int(components[3] * 255))
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
