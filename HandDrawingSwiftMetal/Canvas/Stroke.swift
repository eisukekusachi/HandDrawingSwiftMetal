//
//  Stroke.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/06/19.
//

import UIKit
struct Stroke {
    private (set) var touchesInTexture = PointsWithValues()
    private (set) var smoothPoints = PointsWithValues()
    private (set) var curveWithShade = PointsWithValues()
    private var smoothedIndex: Int = 0
    private var curvedIndex: Int = 0
    private var drawnIndex: Int = 0
    private var isFirstCurveDrawn: Bool = false
    private var atTouchesEnded: Bool = false
    var firstCurve: PointsWithValues? {
        if smoothPoints.count >= 3,
           let points = smoothPoints.get3Points(indices: 0, 1, 2),
           let values = smoothPoints.get3PressureValues(indices: 0, 1, 2) {
            return PointsWithValues(makeFirstCurve(points, values))
        }
        return nil
    }
    var lastCurve: PointsWithValues? {
        if smoothPoints.count >= 3 {
            let i0 = smoothPoints.points.count - 3
            let i1 = smoothPoints.points.count - 2
            let i2 = smoothPoints.points.count - 1
            if let points = smoothPoints.get3Points(indices: (i0), (i1), (i2)),
               let values = smoothPoints.get3PressureValues(indices: (i0), (i1), (i2)) {
                return PointsWithValues(makeLastCurve(points, values))
            }
        } else {
            if let point = smoothPoints.points.last,
               let value = smoothPoints.values.last {
                return PointsWithValues.init(points: [point], values: [value])
            }
        }
        return nil
    }
    // MARK: - Inialize
    init() {}
    init(pointInScreen: CGPoint, ratioOfScreenToTexture: CGFloat) {
        let pointInTexture = pointInScreen.multiplied(ratioOfScreenToTexture)
        touchesInTexture.append(point: pointInTexture)
        smoothPoints.append(point: pointInTexture)
    }
    init(pointInScreen: CGPoint, pressureValue: CGFloat, ratioOfScreenToTexture: CGFloat) {
        let pointInTexture = pointInScreen.multiplied(ratioOfScreenToTexture)
        touchesInTexture.append(point: pointInTexture, pressureValue: pressureValue)
        smoothPoints.append(point: pointInTexture, pressureValue: pressureValue)
    }
    init(pointsInScreen: [CGPoint], ratioOfScreenToTexture: CGFloat, atTouchesEnded: Bool = false) {
        let pointsInTexture = pointsInScreen.multiplied(ratioOfScreenToTexture)
        touchesInTexture.append(points: pointsInTexture)
        if let firstPoint = pointsInTexture.first {
            smoothPoints.append(point: firstPoint)
        }
        self.atTouchesEnded = atTouchesEnded
    }
    // MARK: - Making a curve
    mutating func append(pointInScreen: CGPoint, ratioOfScreenToTexture: CGFloat, atTouchesEnded: Bool = false) {
        let pointInTexture = pointInScreen.multiplied(ratioOfScreenToTexture)
        if touchesInTexture.points.count == 0 {
            smoothPoints.append(point: pointInTexture)
            touchesInTexture.append(point: pointInTexture)
        } else {
            touchesInTexture.append(point: pointInTexture)
        }
        self.atTouchesEnded = atTouchesEnded
    }
    mutating func append(pointInScreen: CGPoint, pressureValue: CGFloat, ratioOfScreenToTexture: CGFloat, atTouchesEnded: Bool = false) {
        let pointInTexture = pointInScreen.multiplied(ratioOfScreenToTexture)
        if touchesInTexture.points.count == 0 {
            smoothPoints.append(point: pointInTexture, pressureValue: pressureValue)
            touchesInTexture.append(point: pointInTexture, pressureValue: pressureValue)
        } else {
            touchesInTexture.append(point: pointInTexture, pressureValue: pressureValue)
        }
        self.atTouchesEnded = atTouchesEnded
    }
    mutating func makeCurve() {
        makeSmoothPoints()
        makeCurvePoints()
    }
    mutating func latestCurveWithShade() -> PointsWithValues? {
        if drawnIndex < curveWithShade.count {
            let points: [CGPoint] = Array(curveWithShade.points[drawnIndex ..< curveWithShade.count])
            let values: [CGFloat] = Array(curveWithShade.values[drawnIndex ..< curveWithShade.count])
            drawnIndex = curveWithShade.count
            return PointsWithValues(points: points, values: values)
        }
        return nil
    }
    private mutating func makeSmoothPoints() {
        while touchesInTexture.count - smoothedIndex >= 2 {
            let i0: Int = smoothedIndex + 0
            let i1: Int = smoothedIndex + 1
            let points = [touchesInTexture.points[i0], touchesInTexture.points[i1]]
            let values = [touchesInTexture.values[i0], touchesInTexture.values[i1]]
            smoothPoints.append(points: Interpolation.split(points, nRatios: [0.5]),
                                pressureValues: Interpolation.split(values, nRatios: [0.5]))
            smoothedIndex += 1
        }
        if atTouchesEnded,
           let lastPoint = touchesInTexture.points.last,
           let lastPressureValue = touchesInTexture.values.last {
            smoothPoints.append(point: lastPoint, pressureValue: lastPressureValue)
        }
    }
    private mutating func makeCurvePoints() {
        if let firstCurve = firstCurve, !isFirstCurveDrawn {
            isFirstCurveDrawn = true
            curveWithShade.append(firstCurve)
        }
        while smoothPoints.count - curvedIndex >= 4 {
            let i0: Int = curvedIndex + 0
            let i1: Int = curvedIndex + 1
            let i2: Int = curvedIndex + 2
            let i3: Int = curvedIndex + 3
            if let points = smoothPoints.get4Points(indices: (i0), (i1), (i2), (i3)),
               let values = smoothPoints.get4PressureValues(indices: (i0), (i1), (i2), (i3)) {
                let curve = makeCurve(points, values)
                curveWithShade.append(curve)
            }
            curvedIndex += 1
        }
        if atTouchesEnded {
            if let lastCurve = lastCurve {
                curveWithShade.append(lastCurve)
            }
        }
    }
    private func makeFirstCurve(_ points: (CGPoint, CGPoint, CGPoint), _ pressure: (CGFloat, CGFloat, CGFloat)) -> PointsWithValues {
        let points = Interpolation.firstCurve(startPoint: points.0, endPoint: points.1, nextPoint: points.2)
        let values = Interpolation.lerp(v0: pressure.0, v1: pressure.1, num: points.count)
        return PointsWithValues(points: points, values: values)
    }
    private func makeCurve(_ points: (CGPoint, CGPoint, CGPoint, CGPoint), _ pressure: (CGFloat, CGFloat, CGFloat, CGFloat)) -> PointsWithValues {
        let points = Interpolation.curve(previousPoint: points.0, startPoint: points.1, endPoint: points.2, nextPoint: points.3)
        let values = Interpolation.lerp(v0: pressure.1, v1: pressure.2, num: points.count)
        return PointsWithValues(points: points, values: values)
    }
    private func makeLastCurve(_ points: (CGPoint, CGPoint, CGPoint), _ pressure: (CGFloat, CGFloat, CGFloat)) -> PointsWithValues {
        let points = Interpolation.lastCurve(previousPoint: points.0, startPoint: points.1, endPoint: points.2, addEndPoint: true)
        let values = Interpolation.lerp(v0: pressure.1, v1: pressure.2, num: points.count)
        return PointsWithValues(points: points, values: values)
    }
    private func getDistanceFromLastPoint(_ points: [CGPoint], _ point: CGPoint) -> CGFloat {
        if let lastPoint = points.last {
            return lastPoint.distance(point)
        }
        return 0.0
    }
}
struct PointsWithValues {
    var points: [CGPoint] = []
    var values: [CGFloat] = []
    var count: Int {
        return points.count == values.count ? points.count : 0
    }
    var first: PointsWithValues? {
        if let point = self.points.first,
           let value = self.values.first {
            return PointsWithValues.init(point: point, value: value)
        }
        return nil
    }
    var last: PointsWithValues? {
        if let point = self.points.last,
           let value = self.values.last {
            return PointsWithValues.init(point: point, value: value)
        }
        return nil
    }
    init(_ object: PointsWithValues?) {
        append(object)
    }
    init(point: CGPoint, value: CGFloat) {
        self.points = [point]
        self.values = [value]
    }
    init(points: [CGPoint] = [], values: [CGFloat] = []) {
        self.points = points
        self.values = values
    }
    init(points: [CGPoint] = []) {
        self.points = points
        self.values = [CGFloat](repeating: 1.0, count: points.count)
    }
    // MARK: Append / remove
    mutating func append(point: CGPoint) {
        self.points += [point]
        self.values += [1.0]
    }
    mutating func append(points: [CGPoint]) {
        self.points += points
        self.values += [CGFloat](repeating: 1.0, count: points.count)
    }
    mutating func append(point: CGPoint, pressureValue: CGFloat) {
        self.points += [point]
        self.values += [pressureValue]
    }
    mutating func append(points: [CGPoint], pressureValues: [CGFloat]) {
        self.points += points
        self.values += pressureValues
    }
    mutating func append(_ touchWithPressure: (CGPoint, CGFloat)) {
        self.points += [touchWithPressure.0]
        self.values += [touchWithPressure.1]
    }
    mutating func append(_ object: PointsWithValues?) {
        guard let obj = object else { return }
        self.points += obj.points
        self.values += obj.values
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
    // MARK: Get / Set
    func get3Points(indices a: Int, _ b: Int, _ c: Int) -> (CGPoint, CGPoint, CGPoint)? {
        if a >= points.count || b >= points.count || c >= points.count { return nil}
        return (points[a], points[b], points[c])
    }
    func get4Points(indices a: Int, _ b: Int, _ c: Int, _ d: Int) -> (CGPoint, CGPoint, CGPoint, CGPoint)? {
        if a >= points.count || b >= points.count || c >= points.count || d >= points.count { return nil}
        return (points[a], points[b], points[c], points[d])
    }
    func get3PressureValues(indices a: Int, _ b: Int, _ c: Int) -> (CGFloat, CGFloat, CGFloat)? {
        if a >= values.count || b >= values.count || c >= values.count { return nil}
        return (values[a], values[b], values[c])
    }
    func get4PressureValues(indices a: Int, _ b: Int, _ c: Int, _ d: Int) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        if a >= values.count || b >= values.count || c >= values.count || d >= values.count { return nil}
        return (values[a], values[b], values[c], values[d])
    }
}
