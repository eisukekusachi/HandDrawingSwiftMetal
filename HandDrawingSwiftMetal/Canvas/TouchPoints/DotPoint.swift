//
//  DotPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/02.
//

import UIKit

struct DotPoint {

    let location: CGPoint
    let alpha: CGFloat

    init(
        location: CGPoint,
        alpha: CGFloat
    ) {
        self.location = location
        self.alpha = alpha
    }

    init(
        touchPoint: TouchPoint,
        matrix: CGAffineTransform? = nil,
        frameSize: CGSize,
        textureSize: CGSize
    ) {
        var location: CGPoint = touchPoint.location
        let alpha: CGFloat = touchPoint.maximumPossibleForce != 0 ? min(touchPoint.force, 1.0) : 1.0

        location = location.scale(srcSize: frameSize, dstSize: textureSize)

        if let matrix {
            let scale = Aspect.getScaleToFit(frameSize, to: textureSize)
            var inverseMatrix = matrix.inverted(flipY: true)
            inverseMatrix.tx *= scale
            inverseMatrix.ty *= scale
            location = location.apply(matrix: inverseMatrix, textureSize: textureSize)
        }

        self.location = location
        self.alpha = alpha
    }

}

extension DotPoint {

    static func average(
        lhs: Self,
        rhs: Self
    ) -> Self {
        let newLocation = CGPoint(x: (lhs.location.x + rhs.location.x) * 0.5,
                                  y: (lhs.location.y + rhs.location.y) * 0.5)

        let newAlpha = (lhs.alpha + rhs.alpha) * 0.5

        return .init(location: newLocation, alpha: newAlpha)
    }

    static func makeFirstCurve(
        previousPoint: Self,
        startPoint: Self,
        endPoint: Self,
        addLastPoint: Bool = false
    ) -> [Self] {
        var curve: [Self] = []

        let locations = Interpolator.firstCurve(
            pointA: previousPoint.location,
            pointB: startPoint.location,
            pointC: endPoint.location,
            addLastPoint: addLastPoint)

        let alphaArray = Interpolator.linear(
            begin: previousPoint.alpha,
            change: startPoint.alpha,
            duration: locations.count)

        for i in 0 ..< locations.count {
            curve.append(
                .init(location: locations[i], alpha: alphaArray[i])
            )
        }

        return curve
    }

    static func makeCurve(
        previousPoint: Self,
        startPoint: Self,
        endPoint: Self,
        nextPoint: Self
    ) -> [Self] {
        var curve: [Self] = []

        let locations = Interpolator.curve(
            previousPoint: previousPoint.location,
            startPoint: startPoint.location,
            endPoint: endPoint.location,
            nextPoint: nextPoint.location)

        let alphaArray = Interpolator.linear(
            begin: startPoint.alpha,
            change: endPoint.alpha,
            duration: locations.count)

        for i in 0 ..< locations.count {
            curve.append(
                .init(location: locations[i], alpha: alphaArray[i])
            )
        }

        return curve
    }

    static func makeLastCurve(
        startPoint: Self,
        endPoint: Self,
        nextPoint: Self,
        addLastPoint: Bool = false
    ) -> [Self] {
        var curve: [Self] = []

        let locations = Interpolator.lastCurve(
            pointA: startPoint.location,
            pointB: endPoint.location,
            pointC: nextPoint.location,
            addLastPoint: addLastPoint)

        let alphaArray = Interpolator.linear(
            begin: endPoint.alpha,
            change: nextPoint.alpha,
            duration: locations.count)

        for i in 0 ..< locations.count {
            curve.append(
                .init(location: locations[i], alpha: alphaArray[i])
            )
        }

        return curve
    }

}
