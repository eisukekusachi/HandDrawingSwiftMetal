//
//  CGVectorExtension.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import CoreGraphics
import SpriteKit
extension CGVector {
    init(_ aPoint: CGPoint, to bPoint: CGPoint) {
        self.init(dx: bPoint.x - aPoint.x, dy: bPoint.y - aPoint.y)
    }
    init(angleRadians: CGFloat, length: CGFloat) {
        let dx = cos(angleRadians) * length
        let dy = sin(angleRadians) * length
        self.init(dx: dx, dy: dy)
    }
    init(angleDegrees: CGFloat, length: CGFloat) {
        self.init(angleRadians: angleDegrees / 180.0 * .pi, length: length)
    }
    func reverse() -> CGVector {
        return CGVector(dx: self.dx * -1.0, dy: self.dy * -1.0)
    }
    mutating func negate() {
        dx *= -1
        dy *= -1
    }
    func angleRadians() -> CGFloat {
        return atan2(dy, dx)
    }
    func angleDegrees() -> CGFloat {
        return angleRadians() * 180.0 / .pi
    }
    func length() -> CGFloat {
        return sqrt(pow(dx, 2) + pow(dy, 2))
    }
    func normalized() -> CGVector {
        let len = length()
        return len > 0 ? self / len : CGVector.zero
    }
    mutating func normalize() -> CGVector {
        self = normalized()
        return self
    }
    func resizeTo(length: CGFloat) -> CGVector {
        var vector = self
        if dx == 0 && dy == 0 {
            return vector
        } else if dx == 0 {
            vector.dx = dx
            vector.dy = length * (dy / abs(dy))
            return vector
        } else if dy == 0 {
            vector.dx = length * (dx / abs(dx))
            vector.dy = dy
            return vector
        } else {
            let proportion = abs(dy / dx)
            let x =  sqrt(pow(length, 2) / (1 + pow(proportion, 2)))
            let y = proportion * x
            vector.dx = x * round(dx / abs(dx))
            vector.dy = y * round(dy / abs(dy))
            return vector
        }
    }
    func dotProduct(_ vector: CGVector) -> CGFloat {
        return self.dx * vector.dx + self.dy * vector.dy
    }
    func getRadian(_ vector: CGVector) -> CGFloat {
        let divisor: CGFloat = self.length() * vector.length()
        return divisor != 0 ? acos(dotProduct(vector) / divisor) : 0.0
    }
}
public func + (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}
public func - (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx - right.dx, dy: left.dy - right.dy)
}
public func * (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx * right.dx, dy: left.dy * right.dy)
}
public func * (vector: CGVector, scalar: CGFloat) -> CGVector {
    return CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
}
public func / (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx / right.dx, dy: left.dy / right.dy)
}
public func / (vector: CGVector, scalar: CGFloat) -> CGVector {
    return CGVector(dx: vector.dx / scalar, dy: vector.dy / scalar)
}
public func lerp(start: CGVector, end: CGVector, t: CGFloat) -> CGVector {
    return start + (end - start) * t
}
