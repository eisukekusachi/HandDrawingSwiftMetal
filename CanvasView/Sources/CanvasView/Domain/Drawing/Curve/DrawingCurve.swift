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

    func markFirstCurveAsDrawn()

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
            markFirstCurveAsDrawn()
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
            let brightnessArray = Interpolator.makeLinearInterpolationValues(
                begin: points.previousPoint.brightness,
                end: points.startPoint.brightness,
                shouldIncludeEndPoint: false,
                duration: bezierCurvePoints.count
            )
            let diameterArray = Interpolator.makeLinearInterpolationValues(
                begin: points.previousPoint.diameter,
                end: points.startPoint.diameter,
                shouldIncludeEndPoint: false,
                duration: bezierCurvePoints.count
            )
            let blurArray = Interpolator.makeLinearInterpolationValues(
                begin: points.previousPoint.blurSize,
                end: points.startPoint.blurSize,
                shouldIncludeEndPoint: false,
                duration: bezierCurvePoints.count
            )

            for i in 0 ..< bezierCurvePoints.count {
                curve.append(
                    .init(
                        location: bezierCurvePoints[i],
                        brightness: brightnessArray[i],
                        diameter: diameterArray[i],
                        blurSize: blurArray[i]
                    )
                )
            }
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
                let brightnessArray = Interpolator.makeLinearInterpolationValues(
                    begin: points.startPoint.brightness,
                    end: points.endPoint.brightness,
                    shouldIncludeEndPoint: false,
                    duration: bezierCurvePoints.count
                )
                let diameterArray = Interpolator.makeLinearInterpolationValues(
                    begin: points.startPoint.diameter,
                    end: points.endPoint.diameter,
                    shouldIncludeEndPoint: false,
                    duration: bezierCurvePoints.count
                )
                let blurArray = Interpolator.makeLinearInterpolationValues(
                    begin: points.startPoint.blurSize,
                    end: points.endPoint.blurSize,
                    shouldIncludeEndPoint: false,
                    duration: bezierCurvePoints.count
                )

                for i in 0 ..< bezierCurvePoints.count {
                    curve.append(
                        .init(
                            location: bezierCurvePoints[i],
                            brightness: brightnessArray[i],
                            diameter: diameterArray[i],
                            blurSize: blurArray[i]
                        )
                    )
                }
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
            let brightnessArray = Interpolator.makeLinearInterpolationValues(
                begin: points.startPoint.brightness,
                end: points.endPoint.brightness,
                shouldIncludeEndPoint: true,
                duration: bezierCurvePoints.count
            )
            let diameterArray = Interpolator.makeLinearInterpolationValues(
                begin: points.startPoint.diameter,
                end: points.endPoint.diameter,
                shouldIncludeEndPoint: true,
                duration: bezierCurvePoints.count
            )
            let blurArray = Interpolator.makeLinearInterpolationValues(
                begin: points.startPoint.blurSize,
                end: points.endPoint.blurSize,
                shouldIncludeEndPoint: true,
                duration: bezierCurvePoints.count
            )

            for i in 0 ..< bezierCurvePoints.count {
                curve.append(
                    .init(
                        location: bezierCurvePoints[i],
                        brightness: brightnessArray[i],
                        diameter: diameterArray[i],
                        blurSize: blurArray[i]
                    )
                )
            }
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

/// A struct that defines the points needed to create a first Bézier curve
private struct BezierCurveFirstPoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
}

/// A struct that defines the points needed to create a Bézier curve
private struct BezierCurveIntermediatePoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
    let nextPoint: GrayscaleDotPoint
}

/// A struct that defines the points needed to create a last Bézier curve
private struct BezierCurveLastPoints {
    let previousPoint: GrayscaleDotPoint
    let startPoint: GrayscaleDotPoint
    let endPoint: GrayscaleDotPoint
}
