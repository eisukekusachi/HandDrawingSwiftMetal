//
//  GrayscaleDotPointDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import CanvasView
import UIKit

public extension GrayscaleDotPoint {

    static func generate(
        location: CGPoint = .zero,
        brightness: CGFloat = 0.0,
        diameter: CGFloat = 0.0,
        blurSize: CGFloat = 0.0
    ) -> Self {
        .init(
            location: location,
            brightness: brightness,
            diameter: diameter,
            blurSize: blurSize
        )
    }
}
