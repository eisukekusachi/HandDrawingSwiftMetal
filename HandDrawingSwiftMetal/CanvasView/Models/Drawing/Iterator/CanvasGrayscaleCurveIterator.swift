//
//  CanvasGrayscaleCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

protocol CanvasGrayscaleCurveIterator {

    typealias T = CanvasGrayscaleDotPoint

    var iterator: Iterator<T> { get }

    var currentTouchPhase: UITouch.Phase { get }

    var hasArrayThreeElementsButNoFirstCurveCreated: Bool { get }

    func appendToIterator(
        points: [T],
        touchPhase: UITouch.Phase
    )

    func makeCurvePointsFromIterator() -> [CanvasGrayscaleDotPoint]?

    func clear()
}

extension CanvasGrayscaleCurveIterator {

    /// Is the drawing finished successfully
    var isDrawingComplete: Bool {
        [UITouch.Phase.ended].contains(currentTouchPhase)
    }

    /// Is the drawing finished
    var isDrawingFinished: Bool {
        [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(currentTouchPhase)
    }

    var isCurrentlyDrawing: Bool {
        iterator.array.count != 0
    }

    /// Makes an array of first curve points from an iterator
    func makeFirstCurvePoints() -> [CanvasGrayscaleDotPoint] {
        var curve: [CanvasGrayscaleDotPoint] = []

        if iterator.array.count >= 3,
           let points = iterator.getFirstBezierCurvePoints() {

            let bezierCurvePoints = BezierCurve.makeFirstCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: false
            )
            curve.append(
                contentsOf: CanvasGrayscaleDotPoint.interpolateToMatchPointCount(
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
    ) -> [CanvasGrayscaleDotPoint] {
        var curve: [CanvasGrayscaleDotPoint] = []

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
                contentsOf: CanvasGrayscaleDotPoint.interpolateToMatchPointCount(
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
    func makeLastCurvePoints() -> [CanvasGrayscaleDotPoint] {
        var curve: [CanvasGrayscaleDotPoint] = []

        if iterator.array.count >= 3,
           let points = iterator.getLastBezierCurvePoints() {

            let bezierCurvePoints = BezierCurve.makeLastCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: true
            )
            curve.append(
                contentsOf: CanvasGrayscaleDotPoint.interpolateToMatchPointCount(
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
