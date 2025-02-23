//
//  DrawingCurveFingerIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// An iterator for real-time finger drawing with `UITouch.Phase`
final class DrawingCurveFingerIterator: Iterator<GrayscaleDotPoint>, DrawingCurveIterator {

    var touchPhase: UITouch.Phase = .began

    private(set) var tmpIterator = Iterator<GrayscaleDotPoint>()

    private var isFirstCurveHasBeenCreated: Bool = false

    override func reset() {
        super.reset()

        tmpIterator.reset()

        touchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}

extension DrawingCurveFingerIterator {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !isFirstCurveHasBeenCreated

        if isFirstCurveToBeCreated {
            isFirstCurveHasBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

    func appendToIterator(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        tmpIterator.append(points)
        self.touchPhase = touchPhase

        makeSmoothCurve()
    }

}

extension DrawingCurveFingerIterator {

    private func makeSmoothCurve() {
        if (tmpIterator.array.count != 0 && self.array.count == 0),
           let firstElement = tmpIterator.array.first {
            self.append(firstElement)
        }

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = GrayscaleDotPoint.average(
                subsequence[0],
                subsequence[1]
            )
            self.append(dotPoint)
        }

        if touchPhase == .ended,
            let lastElement = tmpIterator.array.last {
            self.append(lastElement)
        }
    }

}
