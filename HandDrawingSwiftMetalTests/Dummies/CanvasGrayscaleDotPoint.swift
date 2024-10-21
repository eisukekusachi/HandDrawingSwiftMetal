//
//  CanvasGrayscaleDotPoint.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import UIKit
@testable import HandDrawingSwiftMetal

extension CanvasGrayscaleDotPoint {

    static func generate(
        location: CGPoint = .zero,
        diameter: CGFloat = 0.0,
        brightness: CGFloat = 0.0,
        blurSize: CGFloat = 0.0
    ) -> CanvasGrayscaleDotPoint {
        .init(
            location: location,
            diameter: diameter,
            brightness: brightness,
            blurSize: blurSize
        )
    }

}
