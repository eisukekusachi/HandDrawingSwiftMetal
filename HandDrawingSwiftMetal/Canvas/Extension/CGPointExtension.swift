//
//  CGPointExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
extension CGPoint {
    func add(vector: CGVector) -> CGPoint {
        return CGPoint(x: vector.dx + self.x, y: vector.dy + self.y)
    }
    func add(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x + self.x, y: point.y + self.y)
    }
    func to(_ target: CGPoint) -> CGPoint {
        return CGPoint(x: target.x - self.x, y: target.y - self.y)
    }
    func center(_ target: CGPoint) -> CGPoint {
        return CGPoint(x: (x + target.x) * 0.5, y: (y + target.y) * 0.5)
    }
    func radian(to: CGPoint) -> CGFloat {
        let resultY: CGFloat = (CGFloat(to.y) - CGFloat(y))
        let resultX: CGFloat = (CGFloat(to.x) - CGFloat(x))
        return atan2(resultY, resultX)
    }
    func radian(from: CGPoint) -> CGFloat {
        let resultY: CGFloat = (CGFloat(y) - CGFloat(from.y))
        let resultX: CGFloat = (CGFloat(x) - CGFloat(from.x))
        return atan2(resultY, resultX)
    }
    func angle(to: CGPoint) -> CGFloat {
        let toDegree: CGFloat = 180.0 / 3.14
        let resultY: CGFloat = (CGFloat(to.y) - CGFloat(y))
        let resultX: CGFloat = (CGFloat(to.x) - CGFloat(x))
        return atan2(resultY, resultX) * toDegree
    }
    func angle(from: CGPoint) -> CGFloat {
        let toDegree: CGFloat = 180.0 / 3.14
        let resultY: CGFloat = (CGFloat(y) - CGFloat(from.y))
        let resultX: CGFloat = (CGFloat(x) - CGFloat(from.x))
        return atan2(resultY, resultX) * toDegree
    }
    func distance(_ to: CGPoint?) -> CGFloat {
        guard let value = to else { return 0 }
        return sqrt(pow(value.x - x, 2) + pow(value.y - y, 2))
    }
    func multiplied(_ value: CGFloat) -> CGPoint {
        return CGPoint(x: x * value, y: y * value)
    }
    func divided(_ size: CGSize) -> CGPoint {
        return CGPoint(x: x / size.width, y: y / size.height)
    }
    func multiBy2Sub1() -> CGPoint {
        return CGPoint(x: x * 2.0 - 1.0,
                       y: y * 2.0 - 1.0)
    }
}
