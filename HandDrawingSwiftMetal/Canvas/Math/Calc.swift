//
//  Calc.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/02/05.
//

import Foundation

enum Calc {
    
    static func add(point: CGPoint, vector: CGVector) -> CGPoint {
        return CGPoint(x: vector.dx + point.x, y: vector.dy + point.y)
    }
    static func average(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        return CGPoint(x: (lhs.x + rhs.x) * 0.5, y: (lhs.y + rhs.y) * 0.5)
    }
    static func angle(_ lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let toDegree: CGFloat = 180.0 / 3.14
        let resultY: CGFloat = (CGFloat(rhs.y) - CGFloat(lhs.y))
        let resultX: CGFloat = (CGFloat(rhs.x) - CGFloat(lhs.x))
        return atan2(resultY, resultX) * toDegree
    }
    static func distance(_ lhs: CGPoint, to rhs: CGPoint?) -> CGFloat {
        guard let rhs = rhs else { return 0 }
        return sqrt(pow(rhs.x - lhs.x, 2) + pow(rhs.y - lhs.y, 2))
    }
    
    static func getOffsetForCentering(src: CGSize, dst: CGSize) -> CGPoint {
        return CGPoint(x: dst.width * 0.5 - src.width * 0.5,
                       y: dst.height * 0.5 - src.height * 0.5)
    }
    static func getCenter(_ size: CGSize) -> CGPoint {
        return CGPoint(x: size.width * 0.5,
                       y: size.height * 0.5)
    }
    static func getLength(_ vector: CGVector) -> CGFloat {
        return sqrt(pow(vector.dx, 2) + pow(vector.dy, 2))
    }
    static func getReversedVector(_ vector: CGVector) -> CGVector {
        return CGVector(dx: vector.dx * -1.0, dy: vector.dy * -1.0)
    }
    static func getResizedVector(_ vector: CGVector, length: CGFloat) -> CGVector {
        var vector = vector
        
        if vector.dx == 0 && vector.dy == 0 {
            return vector
            
        } else if vector.dx == 0 {
            vector.dy = length * (vector.dy / abs(vector.dy))
            return vector
            
        } else if vector.dy == 0 {
            vector.dx = length * (vector.dx / abs(vector.dx))
            return vector
            
        } else {
            let proportion = abs(vector.dy / vector.dx)
            let x = sqrt(pow(length, 2) / (1 + pow(proportion, 2)))
            let y = proportion * x
            vector.dx = x * round(vector.dx / abs(vector.dx))
            vector.dy = y * round(vector.dy / abs(vector.dy))
            return vector
        }
    }
    static func getRadian(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        let dotProduct = lhs.dx * rhs.dx + lhs.dy * rhs.dy
        let divisor: CGFloat = Calc.getLength(lhs) * Calc.getLength(rhs)
        
        return divisor != 0 ? acos(dotProduct / divisor) : 0.0
    }
}
