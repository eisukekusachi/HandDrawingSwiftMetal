//
//  DrawingCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import Foundation

/// An iterator for realtime drawing with `UITouch.Phase`
public protocol DrawingCurve: Iterator<GrayscaleDotPoint> {

    var touchPhase: TouchPhase { get }

    func isFirstCurveNeeded() -> Bool

    func curvePoints() -> [GrayscaleDotPoint]

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    )

    func reset()
}

public extension DrawingCurve {

    func curvePoints(
        firstDuration: Int? = nil,
        intermediateDuration: Int? = nil,
        lastDuration: Int? = nil
    ) -> [GrayscaleDotPoint] {
        var result: [GrayscaleDotPoint] = []

        guard array.count >= 3 else { return [] }

        if isFirstCurveNeeded() {
            result.append(
                contentsOf: makeFirstCurvePoints(duration: firstDuration)
            )
        }

        result.append(
            contentsOf: makeIntermediateCurvePoints(duration: intermediateDuration)
        )

        if touchPhase == .ended {
            result.append(
                contentsOf: makeLastCurvePoints(duration: lastDuration)
            )
        }

        return result
    }

    func curvePoints() -> [GrayscaleDotPoint] {
        curvePoints(
            firstDuration: nil,
            intermediateDuration: nil,
            lastDuration: nil
        )
    }

    /// Makes an array of first curve points from an iterator
    func makeFirstCurvePoints(duration: Int? = nil) -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if let points = self.getBezierCurveFirstPoints() {

            let bezierCurvePoints = BezierCurve.makeFirstCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: false,
                duration: duration
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
        duration: Int? = nil
    ) -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if let points = self.getBezierCurveIntermediatePointsWithFixedRange4() {
            points.enumerated().forEach { (index, points) in
                let bezierCurvePoints = BezierCurve.makeIntermediateCurvePoints(
                    previousPoint: points.previousPoint.location,
                    startPoint: points.startPoint.location,
                    endPoint: points.endPoint.location,
                    nextPoint: points.nextPoint.location,
                    shouldIncludeEndPoint: false,
                    duration: duration
                )
                curve.append(
                    contentsOf: GrayscaleDotPoint.interpolateToMatchPointCount(
                        targetPoints: bezierCurvePoints,
                        interpolationStart: points.startPoint,
                        interpolationEnd: points.endPoint,
                        shouldIncludeEndPoint: false
                    )
                )
            }
        }
        return curve
    }

    /// Makes an array of last curve points from an iterator
    func makeLastCurvePoints(duration: Int? = nil) -> [GrayscaleDotPoint] {
        var curve: [GrayscaleDotPoint] = []

        if let points = self.getBezierCurveLastPoints() {

            let bezierCurvePoints = BezierCurve.makeLastCurvePoints(
                pointA: points.previousPoint.location,
                pointB: points.startPoint.location,
                pointC: points.endPoint.location,
                shouldIncludeEndPoint: true,
                duration: duration
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

private extension Iterator<GrayscaleDotPoint> {

    func getBezierCurveFirstPoints() -> BezierCurveFirstPoints? {
        guard array.count >= 3 else { return nil }

        return .init(
            previousPoint: array[0],
            startPoint: array[1],
            endPoint: array[2]
        )
    }

    func getBezierCurveIntermediatePointsWithFixedRange4() -> [BezierCurveIntermediatePoints]? {
        guard array.count >= 4 else { return nil }

        var array: [BezierCurveIntermediatePoints] = []

        while let subsequence = next(range: 4) {
            array.append(
                .init(
                    previousPoint: subsequence[0],
                    startPoint: subsequence[1],
                    endPoint: subsequence[2],
                    nextPoint: subsequence[3]
                )
            )
        }
        return array
    }

    func getBezierCurveLastPoints() -> BezierCurveLastPoints? {
        guard array.count >= 3 else { return nil }

        return .init(
            previousPoint: array[array.count - 3],
            startPoint: array[array.count - 2],
            endPoint: array[array.count - 1]
        )
    }
}
