//
//  Interpolation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

enum Interpolator {

    static func createCubicCurvePoints(
        movePoint: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        endPoint: CGPoint,
        duration: Int,
        shouldAddEndPoint: Bool
    ) -> [CGPoint] {

        var result: [CGPoint] = []

        let duration = max(duration, 1)

        var t: Float = 0.0
        let step: Float = 1.0 / Float(duration)

        for _ in 0 ..< duration {
            let moveX = movePoint.x * CGFloat(powf(1.0 - t, 3.0))
            let control1X = controlPoint1.x * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2X = controlPoint2.x * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endX = endPoint.x * CGFloat(powf(t, 3))

            let moveY = movePoint.y * CGFloat(powf(1.0 - t, 3.0))
            let control1Y = controlPoint1.y * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2Y = controlPoint2.y * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endY = endPoint.y * CGFloat(powf(t, 3.0))

            result.append(
                .init(
                    x: moveX + control1X + control2X + endX,
                    y: moveY + control1Y + control2Y + endY
                )
            )

            t += step
        }

        if shouldAddEndPoint {
            result.append(endPoint)
        }

        return result
    }

    static func createLinearInterpolationValues(
        begin: CGFloat,
        end: CGFloat,
        duration: Int,
        shouldAddEndPoint: Bool
    ) -> [CGFloat] {

        var result: [CGFloat] = []

        let difference = (end - begin)

        let duration = max(duration, 1)

        for t in 0 ..< duration {
            let normalizedValue = CGFloat(Float(t) / Float(duration))
            result.append(difference * normalizedValue + begin)
        }

        if shouldAddEndPoint {
            result.append(end)
        }

        return result
    }
}

private extension CGVector {

    init(leftHandSide: CGPoint, rightHandSide: CGPoint) {
        self.init(
            dx: leftHandSide.x - rightHandSide.x,
            dy: leftHandSide.y - rightHandSide.y
        )
    }
}
