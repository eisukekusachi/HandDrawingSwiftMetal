//
//  GrayscaleCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

protocol GrayscaleCurve {

    typealias T = GrayscaleTexturePoint

    var iterator: Iterator<T> { get }

    /// A variable used to get elements from the array starting from the next element after this point
    var startAfterPoint: TouchPoint? { get set }

    /// The key currently used in the Dictionary
    var currentDictionaryKey: TouchHashValue? { get set }

    func appendToIterator(
        points: [T],
        touchPhase: UITouch.Phase
    )

    func makeCurvePointsFromIterator(
        touchPhase: UITouch.Phase
    ) -> [T]

    func reset()

}

extension GrayscaleCurve {

    func makeCurvePoints(
        atEnd: Bool = false
    ) -> [T] {

        var curve: [T] = []

        while let subsequence = iterator.next(range: 4) {

            if iterator.isFirstProcessing {
                curve.append(
                    contentsOf: makeFirstCurve(
                        previousPoint: iterator.array[0],
                        startPoint: iterator.array[1],
                        endPoint: iterator.array[2],
                        addLastPoint: false
                    )
                )
            }

            curve.append(
                contentsOf: makeCurve(
                    previousPoint: subsequence[0],
                    startPoint: subsequence[1],
                    endPoint: subsequence[2],
                    nextPoint: subsequence[3]
                )
            )
        }

        if atEnd {
            if iterator.index == 0 && iterator.array.count >= 3 {
                curve.append(
                    contentsOf: makeFirstCurve(
                        previousPoint: iterator.array[0],
                        startPoint: iterator.array[1],
                        endPoint: iterator.array[2],
                        addLastPoint: false
                    )
                )
            }

            if iterator.array.count >= 3 {

                let index0 = iterator.array.count - 3
                let index1 = iterator.array.count - 2
                let index2 = iterator.array.count - 1

                curve.append(
                    contentsOf: makeLastCurve(
                        startPoint: iterator.array[index0],
                        endPoint: iterator.array[index1],
                        nextPoint: iterator.array[index2],
                        addLastPoint: true
                    )
                )
            }
        }

        return curve
    }
}

extension GrayscaleCurve {

    private func makeFirstCurve(
        previousPoint: T,
        startPoint: T,
        endPoint: T,
        addLastPoint: Bool = false
    ) -> [T] {

        var curve: [T] = []

        let locations = Interpolator.firstCurve(
            pointA: previousPoint.location,
            pointB: startPoint.location,
            pointC: endPoint.location,
            addLastPoint: addLastPoint
        )

        let duration = locations.count

        let brightnessArray = Interpolator.linear(
            begin: previousPoint.brightness,
            change: startPoint.brightness,
            duration: duration
        )

        let diameterArray = Interpolator.linear(
            begin: previousPoint.diameter,
            change: startPoint.diameter,
            duration: duration
        )

        for i in 0 ..< locations.count {
            curve.append(
                .init(
                    location: locations[i],
                    diameter: diameterArray[i],
                    brightness: brightnessArray[i]
                )
            )
        }

        return curve
    }

    private func makeCurve(
        previousPoint: T,
        startPoint: T,
        endPoint: T,
        nextPoint: T
    ) -> [T] {

        var curve: [T] = []

        let locations = Interpolator.curve(
            previousPoint: previousPoint.location,
            startPoint: startPoint.location,
            endPoint: endPoint.location,
            nextPoint: nextPoint.location
        )

        let duration = locations.count

        let brightnessArray = Interpolator.linear(
            begin: previousPoint.brightness,
            change: startPoint.brightness,
            duration: duration
        )

        let diameterArray = Interpolator.linear(
            begin: previousPoint.diameter,
            change: startPoint.diameter,
            duration: duration
        )

        for i in 0 ..< locations.count {
            curve.append(
                .init(
                    location: locations[i],
                    diameter: diameterArray[i],
                    brightness: brightnessArray[i]
                )
            )
        }

        return curve
    }

    private func makeLastCurve(
        startPoint: T,
        endPoint: T,
        nextPoint: T,
        addLastPoint: Bool = false
    ) -> [T] {

        var curve: [T] = []

        let locations = Interpolator.lastCurve(
            pointA: startPoint.location,
            pointB: endPoint.location,
            pointC: nextPoint.location,
            addLastPoint: addLastPoint
        )

        let duration = locations.count

        let brightnessArray = Interpolator.linear(
            begin: startPoint.brightness,
            change: endPoint.brightness,
            duration: duration
        )

        let diameterArray = Interpolator.linear(
            begin: startPoint.diameter,
            change: endPoint.diameter,
            duration: duration
        )

        for i in 0 ..< locations.count {
            curve.append(
                .init(
                    location: locations[i],
                    diameter: diameterArray[i],
                    brightness: brightnessArray[i]
                )
            )
        }

        return curve
    }

}
