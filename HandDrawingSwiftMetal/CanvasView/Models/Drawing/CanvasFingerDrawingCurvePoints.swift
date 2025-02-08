//
//  CanvasFingerDrawingCurvePoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit
/// A class that saves points in real-time to an iterator, then generates a smooth curve based on those points
/// - Parameters:
///   - iterator: An iterator that stores the average position of `tmpIterator`
///   - tmpIterator: An iterator that stores points
///   - currentTouchPhase: Manages the touch phases from the beginning to the end of drawing a single line
final class CanvasFingerDrawingCurvePoints: CanvasDrawingCurvePoints {
    var iterator = Iterator<CanvasGrayscaleDotPoint>()

    var currentTouchPhase: UITouch.Phase = .began

    /// A key currently in use in the finger touch dictionary
    var dictionaryKey: CanvasTouchHashValue

    /// A variable used to get elements from the array starting from the next element after this point
    private(set) var latestTouchPoint: CanvasTouchPoint?

    private(set) var tmpIterator = Iterator<CanvasGrayscaleDotPoint>()

    private var isFirstCurveHasBeenCreated: Bool = false

    init(dictionaryKey: CanvasTouchHashValue) {
        self.dictionaryKey = dictionaryKey
    }

}

extension CanvasFingerDrawingCurvePoints {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        let isFirstCurveToBeCreated = iterator.array.count >= 3 && !isFirstCurveHasBeenCreated

        if isFirstCurveToBeCreated {
            isFirstCurveHasBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

    func getLatestTouchPoints(from dictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) -> [CanvasTouchPoint] {
        guard
            let touchPoints = dictionary[dictionaryKey]
        else { return [] }

        let latestTouchPoints = touchPoints.elements(after: latestTouchPoint) ?? touchPoints
        latestTouchPoint = latestTouchPoints.last

        return latestTouchPoints
    }

    func appendToIterator(
        points: [CanvasGrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        tmpIterator.append(points)
        currentTouchPhase = touchPhase

        // Add the first point.
        if (tmpIterator.array.count != 0 && iterator.array.count == 0),
           let firstElement = tmpIterator.array.first {
            iterator.append(firstElement)
        }

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = CanvasGrayscaleDotPoint.average(
                subsequence[0],
                subsequence[1]
            )
            iterator.append(dotPoint)
        }

        if touchPhase == .ended,
            let lastElement = tmpIterator.array.last {
            iterator.append(lastElement)
        }
    }

    func reset() {
        tmpIterator.reset()
        iterator.reset()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}
