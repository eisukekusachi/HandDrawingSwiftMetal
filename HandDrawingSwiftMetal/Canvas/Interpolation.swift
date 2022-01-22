//
//  Interpolation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
class Interpolation {
    static let handleMaxLengthRatio: CGFloat = 0.38
    class func lerp(v0: CGFloat, v1: CGFloat, num: Int) -> [CGFloat] {
        var result: [CGFloat] = []
        for t in 0 ..< num {
            result.append(((v1 - v0) / CGFloat(num)) * CGFloat(t) + v0)
        }
        return result
    }
    class func bezierCurve(a: CGPoint, b: CGPoint, c: CGPoint, d: CGPoint, addEndPoint: Bool = false) -> [CGPoint] {
        let previousPoint = a
        let startPoint = b
        let endPoint = c
        let nextPoint = d
        let abVector = CGVector(previousPoint, to: startPoint)
        let bcVector = CGVector(startPoint, to: endPoint)
        let cdVector = CGVector(endPoint, to: nextPoint)
        let abcVector = CGVector(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)
        let dcbVector = CGVector(dx: bcVector.dx + cdVector.dx, dy: bcVector.dy + cdVector.dy).reverse()
        let cp0Vector = abcVector.resizeTo(
            length: max(0.0, (abVector.getRadian(bcVector.reverse()) / .pi)) * (bcVector.length() * handleMaxLengthRatio)
        )
        let cp1Vector = dcbVector.resizeTo(
            length: max(0.0, (bcVector.getRadian(cdVector.reverse()) / .pi)) * (bcVector.length() * handleMaxLengthRatio)
        )
        let cp0 = CGPoint(x: cp0Vector.dx + startPoint.x, y: cp0Vector.dy + startPoint.y)
        let cp1 = CGPoint(x: cp1Vector.dx + endPoint.x, y: cp1Vector.dy + endPoint.y)
        let circumference: Int = Int(startPoint.distance(cp0) + cp0.distance(cp1) + cp1.distance(endPoint))
        let pointNum: Int = max(1, circumference)
        return Interpolation.cubicCurve(movePoint: startPoint,
                                        controlPoint1: cp0,
                                        controlPoint2: cp1,
                                        endPoint: endPoint,
                                        pointNum: pointNum,
                                        addEndPoint: addEndPoint)
    }
    class func firstCurve(a: CGPoint, b: CGPoint, c: CGPoint, addEndPoint: Bool = false) -> [CGPoint] {
        let startPoint: CGPoint = a
        let endPoint: CGPoint = b
        let nextPoint: CGPoint = c
        let cbVector = CGVector(nextPoint, to: endPoint)
        let baVector = CGVector(endPoint, to: startPoint)
        let cbaVector = CGVector(dx: cbVector.dx + baVector.dx, dy: cbVector.dy + baVector.dy)
        let cp1Vector = cbaVector.resizeTo(
            length: max(0.0, (cbVector.getRadian(baVector.reverse()) / .pi)) * (baVector.length() * handleMaxLengthRatio)
        )
        let cp1: CGPoint = CGPoint(x: cp1Vector.dx + endPoint.x, y: cp1Vector.dy + endPoint.y)
        if  let cp0: CGPoint = Utils.getAxialSymmetryPoint(cp1, pallarelLine: startPoint, endPoint) {
            let circumference: Int = Int(startPoint.distance(cp0) + cp0.distance(cp1) + cp1.distance(endPoint))
            let pointNum: Int = max(1, circumference)
            return Interpolation.cubicCurve(movePoint: startPoint,
                                            controlPoint1: cp0,
                                            controlPoint2: cp1,
                                            endPoint: endPoint,
                                            pointNum: pointNum,
                                            addEndPoint: addEndPoint)
        }
        return []
    }
    class func endCurve(a: CGPoint, b: CGPoint, c: CGPoint, addEndPoint: Bool = false) -> [CGPoint] {
        let previousPoint: CGPoint = a
        let startPoint: CGPoint = b
        let endPoint: CGPoint = c
        let abVector = CGVector(previousPoint, to: startPoint)
        let bcVector = CGVector(startPoint, to: endPoint)
        let abcVector = CGVector(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy)
        let cp0Vector = abcVector.resizeTo(
            length: max(0.0, (abVector.getRadian(bcVector.reverse()) / .pi)) * (bcVector.length() * handleMaxLengthRatio)
        )
        let cp0: CGPoint = CGPoint(x: cp0Vector.dx + startPoint.x, y: cp0Vector.dy + startPoint.y)
        if  let cp1: CGPoint = Utils.getAxialSymmetryPoint(cp0, pallarelLine: startPoint, endPoint) {
            let circumference: Int = Int(startPoint.distance(cp0) + cp0.distance(cp1) + cp1.distance(endPoint))
            let pointNum: Int = max(1, circumference)
            return Interpolation.cubicCurve(movePoint: startPoint,
                                            controlPoint1: cp0,
                                            controlPoint2: cp1,
                                            endPoint: endPoint,
                                            pointNum: pointNum,
                                            addEndPoint: addEndPoint)
        }
        return []
    }
    class func cubicCurve(movePoint: CGPoint,
                          controlPoint1: CGPoint,
                          controlPoint2: CGPoint,
                          endPoint: CGPoint,
                          pointNum: Int,
                          addEndPoint: Bool = true) -> [CGPoint] {
        var result: [CGPoint] = []
        var t: CGFloat = 0.0
        let step: CGFloat = 1.0 / CGFloat(pointNum)
        for _ in 0 ..< pointNum {
            result.append( CGPoint(x: (movePoint.x * pow(1 - t, 3)) +
                                    (controlPoint1.x * 3 * t * pow(1 - t, 2)) +
                                    (controlPoint2.x * 3 * (1 - t) * pow(t, 2)) +
                                    (endPoint.x * pow(t, 3)),
                                   y: (movePoint.y * pow(1 - t, 3)) +
                                    (controlPoint1.y * 3 * t * pow(1 - t, 2)) +
                                    (controlPoint2.y * 3 * (1 - t) * pow(t, 2)) +
                                    (endPoint.y * pow(t, 3))) )
            t += step
        }
        if addEndPoint {
            result.append(endPoint)
        }
        return result
    }
}
