//
//  Utils.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/01/22.
//

import UIKit
class Utils {
    class func getAxialSymmetryPoint(_ srcPoint: CGPoint, pallarelLine start: CGPoint, _ to: CGPoint) -> CGPoint? {
        let angle = start.angle(to: to)
        let centerPointParallelLine = start.center(to)
        let a0 = srcPoint
        let a1 = CGPoint(x: cos(angle.toRadian()) + srcPoint.x,
                         y: sin(angle.toRadian()) + srcPoint.y)
        let b0 = centerPointParallelLine
        let b1 = CGPoint(x: -sin(angle.toRadian()) + centerPointParallelLine.x,
                         y: cos(angle.toRadian()) + centerPointParallelLine.y)
        if let crossPoint = crossPoint(a: a0, a1, b: b0, b1) {
            let targetAngle = srcPoint.angle(to: crossPoint)
            let targetLength = srcPoint.distance(crossPoint) * 2
            return CGPoint(x: targetLength * cos((targetAngle).toRadian()) + srcPoint.x,
                           y: targetLength * sin((targetAngle).toRadian()) + srcPoint.y)
        }
        return nil
    }
    class func crossPoint(a: CGPoint, _ a1: CGPoint, b: CGPoint, _ b1: CGPoint) -> CGPoint? {
        let vA: CGPoint = CGPoint(x: a1.x - a.x, y: a1.y - a.y)
        let vB: CGPoint = CGPoint(x: b1.x - b.x, y: b1.y - b.y)
        if (vA.x * vB.y - vA.y * vB.x) == 0.0 {
            return nil
        }
        let x12: CGFloat = a1.x - a.x
        let y12: CGFloat = a1.y - a.y
        let x34: CGFloat = b.x - b1.x
        let y34: CGFloat = b.y - b1.y
        let n: CGFloat = x12 * y34 - y12 * x34
        let s: CGFloat = b.x * b1.y - b1.x * b.y
        let m: CGFloat = a1.x * a.y - a.x * a1.y
        return CGPoint(x: (m * x34 - s * x12) / n,
                       y: (m * y34 - s * y12) / n)
    }
}
