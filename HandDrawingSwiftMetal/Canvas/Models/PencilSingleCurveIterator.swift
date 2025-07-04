//
//  PencilSingleCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// An iterator for realtime pencil drawing with `UITouch.Phase`
final class PencilSingleCurveIterator: Iterator<GrayscaleDotPoint>, SingleCurveIterator {

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

    private var hasFirstCurveBeenCreated: Bool = false

    // Even if `singleCurveIterator` already exists, it will be replaced with a new `PencilSingleCurveIterator`
    // whenever a touch with `.began` phase is detected, since pencil input takes precedence.
    static func shouldCreateInstance(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        self.append(points)
        self.touchPhase.send(touchPhase)
    }

    override func reset() {
        super.reset()

        touchPhase.send(.cancelled)
        hasFirstCurveBeenCreated = false
    }

}

extension PencilSingleCurveIterator {

    var isFirstCurveNeeded: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !hasFirstCurveBeenCreated

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

}
