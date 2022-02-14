//
//  DrawingObject.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/02/13.
//

import UIKit
struct DrawingObject {
    var points: [CGPoint] = []
    var values: [CGFloat] = []
    var pointCount: Int {
        return points.count == values.count ? points.count : 0
    }
    init(_ points: [CGPoint] = [], _ values: [CGFloat] = []) {
        self.points = points
        self.values = values
    }
    init(_ points: [CGPoint] = []) {
        self.points = points
        self.values = [CGFloat](repeating: 1.0, count: points.count)
    }
    // Append / remove
    mutating func append(object: DrawingObject?) {
        guard let obj = object else { return }
        self.points += obj.points
        self.values += obj.values
    }
    mutating func append(points: [CGPoint], values: [CGFloat]) {
        self.points += points
        self.values += values
    }
    mutating func append(point: CGPoint, value: CGFloat) {
        self.points += [point]
        self.values += [value]
    }
    mutating func removeFirst() {
        self.points.removeFirst()
        self.values.removeFirst()
    }
    mutating func removeLast() {
        self.points.removeLast()
        self.values.removeLast()
    }
    mutating func removeAll() {
        self.points = []
        self.values = []
    }
    // Get
    func getFirst() -> DrawingObject {
        if let point = self.points.first,
           let value = self.values.first {
            return DrawingObject.init([point], [value])
        } else {
            return DrawingObject()
        }
    }
    func getLast() -> DrawingObject {
        if let point = self.points.last,
           let value = self.values.last {
            return DrawingObject.init([point], [value])
        } else {
            return DrawingObject()
        }
    }
    func get3Points(indices a: Int, _ b: Int, _ c: Int) -> (CGPoint, CGPoint, CGPoint)? {
        if a >= points.count || b >= points.count || c >= points.count { return nil}
        return (points[a], points[b], points[c])
    }
    func get4Points(indices a: Int, _ b: Int, _ c: Int, _ d: Int) -> (CGPoint, CGPoint, CGPoint, CGPoint)? {
        if a >= points.count || b >= points.count || c >= points.count || d >= points.count { return nil}
        return (points[a], points[b], points[c], points[d])
    }
    func get3Values(indices a: Int, _ b: Int, _ c: Int) -> (CGFloat, CGFloat, CGFloat)? {
        if a >= values.count || b >= values.count || c >= values.count { return nil}
        return (values[a], values[b], values[c])
    }
    func get4Values(indices a: Int, _ b: Int, _ c: Int, _ d: Int) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        if a >= values.count || b >= values.count || c >= values.count || d >= values.count { return nil}
        return (values[a], values[b], values[c], values[d])
    }
    mutating func setValue(index: Int, value: CGFloat) {
        if index < self.values.count {
            self.values[index] = value
        }
    }
    // Curve
    func multiplyPoints(by ratio: CGFloat) -> DrawingObject {
        return DrawingObject.init(points.multiplied(ratio), values)
    }
    func smoothed(processedIndex i: inout Int) -> DrawingObject {
        var obj = DrawingObject()
        while self.pointCount - i >= 2 {
            obj.append(points: [self.points[i + 0], self.points[i + 1]].splitted(ratioArray: [0.5]),
                       values: [self.values[i + 0], self.values[i + 1]].splitted(ratioArray: [0.5]))
            i += 1
        }
        return obj
    }
    func curvedAtFirst() -> DrawingObject {
        var obj = DrawingObject()
        if self.pointCount >= 3,
           let points = self.get3Points(indices: 0, 1, 2),
           let values = self.get3Values(indices: 0, 1, 2) {
            obj.append(object: makeFirstCurve(points, values))
        }
        return obj
    }
    func curved(processedIndex i: inout Int) -> DrawingObject {
        var obj = DrawingObject()
        while self.pointCount - i >= 4 {
            if  let points = self.get4Points(indices: (i + 0), (i + 1), (i + 2), (i + 3)),
                let values = self.get4Values(indices: (i + 0), (i + 1), (i + 2), (i + 3)) {
                obj.append(object: makeCurve(points, values))
                i += 1
            }
        }
        return obj
    }
    func curved() -> DrawingObject {
        var i = 0
        var obj = DrawingObject()
        while self.pointCount - i >= 4 {
            if  let points = self.get4Points(indices: (i + 0), (i + 1), (i + 2), (i + 3)),
                let values = self.get4Values(indices: (i + 0), (i + 1), (i + 2), (i + 3)) {
                obj.append(object: makeCurve(points, values))
                i += 1
            }
        }
        return obj
    }
    func curvedAtEnd() -> DrawingObject {
        var obj = DrawingObject()
        if self.points.count >= 3 {
            let i0 = self.points.count - 3
            let i1 = self.points.count - 2
            let i2 = self.points.count - 1
            if  let points = self.get3Points(indices: (i0), (i1), (i2)),
                let values = self.get3Values(indices: (i0), (i1), (i2)) {
                obj.append(object: makeLastCurve(points, values))
            }
        } else {
            if  let point = self.points.last,
                let value = self.values.last {
                obj = DrawingObject.init([point], [value])
            }
        }
        return obj
    }
    private func makeFirstCurve(_ points: (CGPoint, CGPoint, CGPoint), _ values: (CGFloat, CGFloat, CGFloat)) -> DrawingObject {
        let points = Interpolation.firstCurve(startPoint: points.0, endPoint: points.1, nextPoint: points.2)
        let values = Interpolation.lerp(v0: values.0, v1: values.1, num: points.count)
        return DrawingObject(points, values)
    }
    private func makeCurve(_ points: (CGPoint, CGPoint, CGPoint, CGPoint), _ values: (CGFloat, CGFloat, CGFloat, CGFloat)) -> DrawingObject {
        let points = Interpolation.curve(previousPoint: points.0, startPoint: points.1, endPoint: points.2, nextPoint: points.3)
        let values = Interpolation.lerp(v0: values.1, v1: values.2, num: points.count)
        return DrawingObject(points, values)
    }
    private func makeLastCurve(_ points: (CGPoint, CGPoint, CGPoint), _ values: (CGFloat, CGFloat, CGFloat)) -> DrawingObject {
        let points = Interpolation.lastCurve(previousPoint: points.0, startPoint: points.1, endPoint: points.2, addEndPoint: true)
        let values = Interpolation.lerp(v0: values.1, v1: values.2, num: points.count)
        return DrawingObject(points, values)
    }
}
