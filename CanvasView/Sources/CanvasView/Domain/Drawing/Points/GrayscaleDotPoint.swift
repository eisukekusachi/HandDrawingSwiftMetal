//
//  GrayscaleDotPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// A point that has a brightness value
public struct GrayscaleDotPoint: Equatable, Sendable {

    let location: CGPoint

    /// brightness (0.0 ~ 1.0)
    let brightness: CGFloat

    /// The diameter without blur
    let diameter: CGFloat

    /// The size of the blur on one side
    let blurSize: CGFloat

    public init(
        location: CGPoint,
        brightness: CGFloat,
        diameter: CGFloat,
        blurSize: CGFloat = 2.0
    ) {
        self.location = location
        self.brightness = brightness
        self.diameter = diameter
        self.blurSize = blurSize
    }
}

public extension GrayscaleDotPoint {

    static func average(_ left: Self, _ right: Self) -> Self {
        .init(
            location: left.location == right.location ? left.location : CGPoint(
                x: (left.location.x + right.location.x) * 0.5,
                y: (left.location.y + right.location.y) * 0.5
            ),
            brightness: left.brightness == right.brightness ? left.brightness : (left.brightness + right.brightness) * 0.5,
            diameter: left.diameter == right.diameter ? left.diameter : (left.diameter + right.diameter) * 0.5,
            blurSize: left.blurSize == right.blurSize ? left.blurSize : (left.blurSize + right.blurSize) * 0.5
        )
    }
}
