//
//  TouchPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/19.
//

import UIKit

/// A struct representing a point with position and opacity.
struct TouchPoint {
    let location: CGPoint
    let alpha: CGFloat

    init(touch: UITouch, view: UIView, alpha: CGFloat? = nil) {
        self.location = touch.preciseLocation(in: view)
        self.alpha = alpha ?? max(0.0, min(touch.force, 1.0))
    }

    init(location: CGPoint, alpha: CGFloat) {
        self.location = location
        self.alpha = max(0.0, min(alpha, 1.0))
    }
}

extension TouchPoint {
    func apply(matrix: CGAffineTransform, textureSize: CGSize) -> Self {
        var location = self.location

        location = CGPoint(x: location.x - textureSize.width * 0.5,
                           y: location.y - textureSize.height * 0.5)

        location = CGPoint(x: (location.x * matrix.a + location.y * matrix.c + matrix.tx),
                           y: (location.x * matrix.b + location.y * matrix.d + matrix.ty))

        location = CGPoint(x: location.x + textureSize.width * 0.5,
                           y: location.y + textureSize.height * 0.5)

        return TouchPoint(location: location, alpha: self.alpha)
    }

    func center(srcSize: CGSize, dstSize: CGSize) -> Self {
        var location = self.location

        let scaleFrameToTexture = Aspect.getScaleToFit(srcSize, to: dstSize)

        let srcSize = CGSize(width: (srcSize.width * scaleFrameToTexture),
                             height: (srcSize.height * scaleFrameToTexture))

        let offsetForCentering = Calc.getOffsetForCentering(src: srcSize, dst: dstSize)

        location = CGPoint(x: location.x + offsetForCentering.x,
                           y: location.y + offsetForCentering.y)

        return TouchPoint(location: location, alpha: self.alpha)
    }

    func offset(_ offset: CGPoint) -> Self {
        var location = self.location

        location = CGPoint(x: location.x + offset.x,
                           y: location.y + offset.y)

        return TouchPoint(location: location, alpha: self.alpha)
    }

    func scale(srcSize: CGSize, dstSize: CGSize) -> Self {
        var location = self.location

        let scaleFrameToTexture = Aspect.getScaleToFit(srcSize, to: dstSize)

        location = CGPoint(x: (location.x * scaleFrameToTexture),
                           y: (location.y * scaleFrameToTexture))

        return TouchPoint(location: location, alpha: self.alpha)
    }

    static func average(lhs: TouchPoint, rhs: TouchPoint) -> TouchPoint {
        let newLocation = CGPoint(x: (lhs.location.x + rhs.location.x) * 0.5,
                                  y: (lhs.location.y + rhs.location.y) * 0.5)

        let newAlpha = (lhs.alpha + rhs.alpha) * 0.5

        return TouchPoint(location: newLocation, alpha: newAlpha)
    }
}
