//
//  DrawingCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// An iterator for real-time drawing with `UITouch.Phase`
protocol DrawingCurveIterator: Iterator<GrayscaleDotPoint> {

    var touchPhase: UITouch.Phase { get }

    var latestCurvePoints: [GrayscaleDotPoint] { get }

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    )

    func reset()

}

extension DrawingCurveIterator {

    /// Is the drawing finished
    var isDrawingFinished: Bool {
        UITouch.isTouchCompleted(touchPhase)
    }

    var isCurrentlyDrawing: Bool {
        !isDrawingFinished
    }

    /// Makes an array of first curve points from an iterator
    func makeFirstCurvePoints() -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if self.array.count >= 3,
           let points = self.getBezierCurveFirstPoints() {

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

        let pointArray = self.getBezierCurveIntermediatePointsWithFixedRange4()

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

        if self.array.count >= 3,
           let points = self.getBezierCurveLastPoints() {

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
