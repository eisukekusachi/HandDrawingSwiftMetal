//
//  FingerSingleCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// An iterator for real-time finger drawing with `UITouch.Phase`
final class FingerSingleCurveIterator: Iterator<GrayscaleDotPoint>, SingleCurveIterator {

    let touchPhase = CurrentValueSubject<UITouch.Phase, Never>(.cancelled)

    var latestCurvePoints: [GrayscaleDotPoint] {
        var array: [GrayscaleDotPoint] = []

        if isFirstCurveNeeded {
            array.append(contentsOf: makeFirstCurvePoints())
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingFinished {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array
    }

    private(set) var tmpIterator = Iterator<GrayscaleDotPoint>()

    private var hasFirstCurveBeenCreated: Bool = false

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        self.tmpIterator.append(points)
        self.touchPhase.send(touchPhase)

        self.makeSmoothCurve()
    }

    override func reset() {
        super.reset()

        tmpIterator.reset()

        touchPhase.send(.cancelled)
        hasFirstCurveBeenCreated = false
    }

}

extension FingerSingleCurveIterator {

    var isFirstCurveNeeded: Bool {
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

        if touchPhase.value == .ended,
            let lastElement = tmpIterator.array.last {
            self.append(lastElement)
        }
    }

}
