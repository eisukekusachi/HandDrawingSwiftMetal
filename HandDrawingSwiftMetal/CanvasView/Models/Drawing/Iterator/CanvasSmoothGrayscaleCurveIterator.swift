//
//  CanvasSmoothGrayscaleCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class CanvasSmoothGrayscaleCurveIterator: CanvasDrawingCurve {
    var iterator = Iterator<CanvasGrayscaleDotPoint>()

    var currentTouchPhase: UITouch.Phase = .began

    private var isFirstCurveHasBeenCreated: Bool = false

    private var tmpIterator = Iterator<CanvasGrayscaleDotPoint>()

}

extension CanvasSmoothGrayscaleCurveIterator {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        iterator.array.count >= 3 && !isFirstCurveHasBeenCreated
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

    func makeCurvePointsFromIterator() -> [CanvasGrayscaleDotPoint]? {
        var array: [CanvasGrayscaleDotPoint] = []

        if hasArrayThreeElementsButNoFirstCurveCreated {
            array.append(contentsOf: makeFirstCurvePoints())
            isFirstCurveHasBeenCreated = true
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingComplete {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array.count != 0 ? array : nil
    }

    func clear() {
        tmpIterator.clear()
        iterator.clear()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}
