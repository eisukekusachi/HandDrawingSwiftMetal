//
//  CanvasDrawingCurvePoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// A protocol used for real-time drawing using an iterator and a touchPhase
protocol CanvasDrawingCurvePoints {

    typealias T = GrayscaleDotPoint

    var iterator: Iterator<T> { get }

    var currentTouchPhase: UITouch.Phase { get }

    var hasArrayThreeElementsButNoFirstCurveCreated: Bool { get }

    func appendToIterator(
        points: [T],
        touchPhase: UITouch.Phase
    )

    func reset()
}

extension CanvasDrawingCurvePoints {

    /// Is the drawing finished
    var isDrawingFinished: Bool {
        UITouch.isTouchCompleted(currentTouchPhase)
    }

    var isCurrentlyDrawing: Bool {
        !isDrawingFinished
    }

    func makeCurvePointsFromIterator() -> [GrayscaleDotPoint] {
        var array: [GrayscaleDotPoint] = []

        if hasArrayThreeElementsButNoFirstCurveCreated {
            array.append(contentsOf: makeFirstCurvePoints())
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingFinished {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array
    }

    /// Makes an array of first curve points from an iterator
    func makeFirstCurvePoints() -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if iterator.array.count >= 3,
           let points = iterator.getFirstBezierCurvePoints() {

            let bezierCurvePoints = BezierCurve.makeFirstCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: false
            )
            curve.append(
                contentsOf: GrayscaleDotPoint.interpolateToMatchPointCount(
                    targetPoints: bezierCurvePoints,
                    interpolationStart: points.previousPoint,
                    interpolationEnd: points.startPoint,
                    shouldIncludeEndPoint: false
                )
            )
        }
        return curve
    }

    /// Makes an array of intermediate curve points from an iterator, setting the range to 4
    func makeIntermediateCurvePoints(
        shouldIncludeEndPoint: Bool
    ) -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        let pointArray = iterator.getIntermediateBezierCurvePointsWithFixedRange4()

        pointArray.enumerated().forEach { (index, points) in
            let shouldIncludeEndPoint = index == pointArray.count - 1 ? shouldIncludeEndPoint : false

            let bezierCurvePoints = BezierCurve.makeIntermediateCurvePoints(
                previousPoint: points.previousPoint.location,
                startPoint: points.startPoint.location,
                endPoint: points.endPoint.location,
                nextPoint: points.nextPoint.location,
                shouldIncludeEndPoint: shouldIncludeEndPoint
            )
            curve.append(
                contentsOf: GrayscaleDotPoint.interpolateToMatchPointCount(
                    targetPoints: bezierCurvePoints,
                    interpolationStart: points.startPoint,
                    interpolationEnd: points.endPoint,
                    shouldIncludeEndPoint: shouldIncludeEndPoint
                )
            )
        }
        return curve
    }

    /// Makes an array of last curve points from an iterator
    func makeLastCurvePoints() -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if iterator.array.count >= 3,
           let points = iterator.getLastBezierCurvePoints() {

            let bezierCurvePoints = BezierCurve.makeLastCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: true
            )
            curve.append(
                contentsOf: GrayscaleDotPoint.interpolateToMatchPointCount(
                    targetPoints: bezierCurvePoints,
                    interpolationStart: points.startPoint,
                    interpolationEnd: points.endPoint,
                    shouldIncludeEndPoint: true
                )
            )
        }
        return curve
    }

}
