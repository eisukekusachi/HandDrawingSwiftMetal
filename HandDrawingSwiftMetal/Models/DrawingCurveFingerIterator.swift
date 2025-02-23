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

    private var hasFirstCurveBeenCreated: Bool = false

    var latestCurvePoints: [GrayscaleDotPoint] {
        var array: [GrayscaleDotPoint] = []

        if shouldGetFirstCurve {
            array.append(contentsOf: makeFirstCurvePoints())
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingFinished {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array
    }

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        tmpIterator.append(points)
        self.touchPhase = touchPhase

        makeSmoothCurve()
    }

    override func reset() {
        super.reset()

        tmpIterator.reset()

        touchPhase = .began
        hasFirstCurveBeenCreated = false
    }

}

extension DrawingCurveFingerIterator {

    var shouldGetFirstCurve: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !hasFirstCurveBeenCreated

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

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
