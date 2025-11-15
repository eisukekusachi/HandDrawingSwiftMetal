//
//  Interpolation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit

private let handleMaxLengthRatio: CGFloat = 0.38
private let toRadian: CGFloat = (3.14 / 180.0)

enum Interpolator {

    static func firstCurve(
        pointA: CGPoint,
        pointB: CGPoint,
        pointC: CGPoint,
        addLastPoint: Bool = false
    ) -> [CGPoint] {

        let cbVector: CGVector = .init(leftHandSide: pointB, rightHandSide: pointC)
        let baVector: CGVector = .init(leftHandSide: pointA, rightHandSide: pointB)
        let abVector: CGVector = .init(leftHandSide: pointB, rightHandSide: pointA)
        let cbaVector: CGVector = .init(dx: cbVector.dx + baVector.dx, dy: cbVector.dy + baVector.dy)

        let adjustValue1 = Calculate.getRadian(cbVector, Calculate.getReversedVector(baVector)) / .pi
        let length1 = Calculate.getLength(baVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp1Vector = Calculate.getResizedVector(cbaVector, length: length1)
        let cp1: CGPoint = .init(x: cp1Vector.dx + pointB.x, y: cp1Vector.dy + pointB.y)

        let length0 = Calculate.getLength(abVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp0Vector = Calculate.getResizedVector(abVector, length: length0)
        let cp0: CGPoint = .init(x: cp0Vector.dx + pointA.x, y: cp0Vector.dy + pointA.y)

        let circumference = Int(
            Calculate.getLength(pointA, to: cp0) +
            Calculate.getLength(cp0, to: cp1) +
            Calculate.getLength(cp1, to: pointB)
        )

        return Interpolator.cubicCurve(
            movePoint: pointA,
            controlPoint1: cp0,
            controlPoint2: cp1,
            endPoint: pointB,
            totalPointNum: max(1, circumference),
            addLastPoint: addLastPoint
        )
    }
    static func curve(
        previousPoint: CGPoint,
        startPoint: CGPoint,
        endPoint: CGPoint,
        nextPoint: CGPoint,
        addLastPoint: Bool = false
    ) -> [CGPoint] {

        let abVector: CGVector = .init(leftHandSide: startPoint, rightHandSide: previousPoint)
        let bcVector: CGVector = .init(leftHandSide: endPoint, rightHandSide: startPoint)
        let cdVector: CGVector = .init(leftHandSide: nextPoint, rightHandSide: endPoint)
        let abcVector: CGVector = .init(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)
        let dcbVector = Calculate.getReversedVector(
            .init(
                dx: bcVector.dx + cdVector.dx,
                dy: bcVector.dy + cdVector.dy
            )
        )

        let adjustValue0 = Calculate.getRadian(abVector, Calculate.getReversedVector(bcVector)) / .pi
        let length0 = Calculate.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp0Vector = Calculate.getResizedVector(abcVector, length: length0)

        let adjustValue1 = Calculate.getRadian(bcVector, Calculate.getReversedVector(cdVector)) / .pi
        let length1 = Calculate.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue1)
        let cp1Vector = Calculate.getResizedVector(dcbVector, length: length1)

        let cp0: CGPoint = .init(x: cp0Vector.dx + startPoint.x, y: cp0Vector.dy + startPoint.y)
        let cp1: CGPoint = .init(x: cp1Vector.dx + endPoint.x, y: cp1Vector.dy + endPoint.y)
        let circumference = Int(
            Calculate.getLength(startPoint, to: cp0) +
            Calculate.getLength(cp0, to: cp1) +
            Calculate.getLength(cp1, to: endPoint)
        )

        return Interpolator.cubicCurve(
            movePoint: startPoint,
            controlPoint1: cp0,
            controlPoint2: cp1,
            endPoint: endPoint,
            totalPointNum: max(1, circumference),
            addLastPoint: addLastPoint
        )
    }
    static func lastCurve(
        pointA: CGPoint,
        pointB: CGPoint,
        pointC: CGPoint,
        addLastPoint: Bool = false
    ) -> [CGPoint] {

        let abVector: CGVector = .init(leftHandSide: pointB, rightHandSide: pointA)
        let bcVector: CGVector = .init(leftHandSide: pointC, rightHandSide: pointB)
        let cbVector: CGVector = .init(leftHandSide: pointB, rightHandSide: pointC)
        let abcVector: CGVector = .init(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)

        let adjustValue0 = Calculate.getRadian(abVector, Calculate.getReversedVector(bcVector)) / .pi
        let length0 = Calculate.getLength(bcVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp0Vector = Calculate.getResizedVector(abcVector, length: length0)
        let cp0: CGPoint = .init(x: cp0Vector.dx + pointB.x, y: cp0Vector.dy + pointB.y)

        let length1 = Calculate.getLength(cbVector) * handleMaxLengthRatio * max(0.0, adjustValue0)
        let cp1Vector = Calculate.getResizedVector(cbVector, length: length1)
        let cp1: CGPoint = .init(x: cp1Vector.dx + pointC.x, y: cp1Vector.dy + pointC.y)

        let circumference: Int = Int(
            Calculate.getLength(pointB, to: cp0) +
            Calculate.getLength(cp0, to: cp1) +
            Calculate.getLength(cp1, to: pointC)
        )

        return Interpolator.cubicCurve(
            movePoint: pointB,
            controlPoint1: cp0,
            controlPoint2: cp1,
            endPoint: pointC,
            totalPointNum: max(1, circumference),
            addLastPoint: addLastPoint
        )
    }

    static func cubicCurve(
        movePoint: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        endPoint: CGPoint,
        totalPointNum: Int,
        addLastPoint: Bool = true
    ) -> [CGPoint] {

        var result: [CGPoint] = []

        var t: Float = 0.0
        let step: Float = 1.0 / Float(totalPointNum)

        for _ in 0 ..< totalPointNum {
            let movex = movePoint.x * CGFloat(powf(1.0 - t, 3.0))
            let control1x = controlPoint1.x * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2x = controlPoint2.x * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endx = endPoint.x * CGFloat(powf(t, 3))

            let movey = movePoint.y * CGFloat(powf(1.0 - t, 3.0))
            let control1y = controlPoint1.y * CGFloat(3.0 * t * powf(1.0 - t, 2.0))
            let control2y = controlPoint2.y * CGFloat(3.0 * (1.0 - t) * powf(t, 2.0))
            let endy = endPoint.y * CGFloat(powf(t, 3.0))

            result.append(
                .init(
                    x: movex + control1x + control2x + endx,
                    y: movey + control1y + control2y + endy
                )
            )

            t += step
        }
        if addLastPoint {
            result.append(endPoint)
        }

        return result
    }
}

extension Interpolator {
    static func makeCubicCurvePoints(
        movePoint: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        endPoint: CGPoint,
        duration: Int,
        shouldIncludeEndPoint: Bool
    ) -> [CGPoint] {

        var result: [CGPoint] = []

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

        if shouldIncludeEndPoint {
            result.append(endPoint)
        }

        return result
    }

    static func makeLinearInterpolationValues(
        begin: CGFloat,
        end: CGFloat,
        shouldIncludeEndPoint: Bool,
        duration: Int
    ) -> [CGFloat] {

        var result: [CGFloat] = []

        let difference = (end - begin)

        var duration = max(duration, 1)

        if shouldIncludeEndPoint {
            // Subtract 1 from `duration` because the last point will be added to the arrays
            duration -= 1
        }

        for t in 0 ..< duration {
            let normalizedValue = CGFloat(Float(t) / Float(duration))
            result.append(difference * normalizedValue + begin)
        }

        if shouldIncludeEndPoint {
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
