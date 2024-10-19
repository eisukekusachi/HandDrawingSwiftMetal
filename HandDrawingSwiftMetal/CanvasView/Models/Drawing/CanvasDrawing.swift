//
//  CanvasDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import UIKit

/// A model for drawing smooth curves in real-time
final class CanvasDrawing {

    typealias T = CanvasGrayscaleDotPoint

    private let iterator = Iterator<CanvasGrayscaleDotPoint>()

    private var currentTouchPhase: UITouch.Phase?

    private var isFirstCurveHasBeenCreated: Bool = false

}

extension CanvasDrawing {

    func makeDrawingCurvePointsFromIterator() -> [CanvasGrayscaleDotPoint]? {
        var array: [CanvasGrayscaleDotPoint] = []

        if hasArrayThreeElementsButNoFirstCurveCreated {
            array.append(contentsOf: makeFirstCurvePoints())
            setFirstCurveHasBeenCreated()
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingComplete {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array.count != 0 ? array : nil
    }

    var isCurrentlyDrawing: Bool {
        iterator.array.count != 0
    }

    /// Is the drawing finished successfully
    var isDrawingComplete: Bool {
        guard let currentTouchPhase else { return false }
        return [UITouch.Phase.ended].contains(currentTouchPhase)
    }

    /// Is the drawing finished
    var isDrawingFinished: Bool {
        guard let currentTouchPhase else { return false }
        return [UITouch.Phase.ended, UITouch.Phase.cancelled].contains(currentTouchPhase)
    }

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        iterator.array.count >= 3 && !isFirstCurveHasBeenCreated
    }

    func setFirstCurveHasBeenCreated() {
        isFirstCurveHasBeenCreated = true
    }

    func setCurrentTouchPhase(_ touchPhase: UITouch.Phase) {
        currentTouchPhase = touchPhase
    }

    func appendToIterator(_ point: CanvasGrayscaleDotPoint) {
        iterator.append(point)
    }
    func appendToIterator(_ points: [CanvasGrayscaleDotPoint]) {
        iterator.append(points)
    }

    func reset() {
        isFirstCurveHasBeenCreated = false
        currentTouchPhase = nil
        iterator.clear()
    }

}

extension CanvasDrawing {

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
