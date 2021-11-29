//
//  Interpolation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
class Interpolation {
    class func lerp(v0: CGFloat, v1: CGFloat, num: Int) -> [CGFloat] {
        var result: [CGFloat] = []
        for t in 0 ..< num {
            result.append(((v1 - v0) / CGFloat(num)) * CGFloat(t) + v0)
        }
        return result
    }
    class func bezierCurve(a: CGPoint, b: CGPoint, c: CGPoint, d: CGPoint) -> [CGPoint] {
        let handleMaxLengthRatio: CGFloat = 0.38
        let abVector = CGVector(a, to: b)
        let bcVector = CGVector(b, to: c)
        let cdVector = CGVector(c, to: d)
        let maxlen: CGFloat = bcVector.length() * handleMaxLengthRatio
        let bcP1Vector = CGVector(dx: abVector.dx + bcVector.dx, dy: abVector.dy + bcVector.dy).resizeTo(
            length: max(0.0, (bcVector.getRadian(abVector.reverse()) / .pi)) * maxlen
        )
        let cbP2Vector = CGVector(dx: bcVector.dx + cdVector.dx, dy: bcVector.dy + cdVector.dy).reverse().resizeTo(
            length: max(0.0, (cdVector.getRadian(bcVector.reverse()) / .pi)) * maxlen
        )
        let start = b
        let end = c
        let cp1 = CGPoint(x: b.x + bcP1Vector.dx, y: b.y + bcP1Vector.dy)
        let cp2 = CGPoint(x: c.x + cbP2Vector.dx, y: c.y + cbP2Vector.dy)
        let circumference: Int = Int(start.distance(cp1) + cp1.distance(cp2) + cp2.distance(end))
        let pointNum: Int = max(1, circumference)
        return Interpolation.cubicCurve(movePoint: start,
                                        controlPoint1: cp1,
                                        controlPoint2: cp2,
                                        endPoint: end,
                                        pointNum: pointNum,
                                        addEndPoint: false)
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
