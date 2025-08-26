//
//  UIImageExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import UIKit

extension UIImage {

    static func checkerboardImage(
        size: CGSize,
        checkSize: CGFloat = 8,
        light: UIColor = .white,
        dark: UIColor = .lightGray,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let cg = context.cgContext
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let isLight = ((Int(x / checkSize) + Int(y / checkSize)) % 2 == 0)
                    cg.setFillColor((isLight ? light : dark).cgColor)
                    cg.fill(CGRect(x: x, y: y, width: checkSize, height: checkSize))
                    x += checkSize
                }
                y += checkSize
            }
        }
    }
}
