//
//  SmoothPointToCurveConverter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/04/01.
//

import Foundation

class SmoothPointStorage: PointStorage {
    
    typealias Input = [Int: TouchPoint]
    typealias StoredPoints = [Int: [TouchPoint]]
    typealias Output = TouchPoint

    var storedPoints: StoredPoints = [:]
    var iterator = Iterator<Output>()
    var iteratorForSmoothCurve = Iterator<Output>()
    
    func appendPoints(_ input: Input) {
        
        input.keys.forEach { key in
            
            if storedPoints[key] == nil {
                storedPoints[key] = []
            }
            if let elem = input[key] {
                storedPoints[key]?.append(elem)
            }
        }
        
        if let points = storedPoints.first {
            iteratorForSmoothCurve.update(elems: points)
        }
    }
    func getIterator(endProcessing: Bool = false) -> Iterator<Output> {
        
        SmoothPointStorage.makeSmoothIterator(src: iteratorForSmoothCurve, dst: &iterator, endProcessing: endProcessing)
        
        return iterator
    }
    func reset() {
        storedPoints = [:]
        iterator.reset()
        iteratorForSmoothCurve.reset()
    }
}

extension SmoothPointStorage {
    static func average(lhs: TouchPoint, rhs: TouchPoint) -> TouchPoint {

        var point = lhs
        
        let newLocation = CGPoint(x: (lhs.location.x + rhs.location.x) * 0.5,
                                  y: (lhs.location.y + rhs.location.y) * 0.5)
        
        let newAlpha = (lhs.alpha + rhs.alpha) * 0.5
        
        return TouchPoint(location: newLocation, alpha: newAlpha)
    }
    static func makeSmoothIterator(src: Iterator<Output>, dst: inout Iterator<Output>, endProcessing: Bool) {
        // Add the first point.
        if src.array.count != 0 && dst.array.count == 0 {
            if let firstElement = src.array.first {
                dst.append(elem: firstElement)
            }
        }
        
        while let subsequece = src.next(range: 2) {
            dst.append(elem: average(lhs: subsequece[0], rhs: subsequece[1]))
        }
        
        // Add the last point.
        if endProcessing {
            if let lastElement = src.array.last {
                dst.append(elem: lastElement)
            }
        }
    }
}
