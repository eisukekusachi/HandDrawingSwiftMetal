//
//  ColorData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/29.
//

import UIKit

class ColorData {
    let colorArray: [UIColor] = [
        .black,
        Converter.color((255, 0, 0, 200))
        ]
    
    let alpha: Int = 200
}

enum Converter {
    static func color(_ color: (Int, Int, Int, Int)) -> UIColor {
        
        let colorR = CGFloat(color.0) / 255.0
        let colorG = CGFloat(color.1) / 255.0
        let colorB = CGFloat(color.2) / 255.0
        let colorA = CGFloat(color.3) / 255.0
        
        return UIColor(red: colorR, green: colorG, blue: colorB, alpha: colorA)
    }
}
