//
//  SmoothDrawingCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// An iterator for creating a smooth curve in real-time using touch phases
public final class SmoothDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

    public let touchPhase = CurrentValueSubject<TouchPhase, Never>(.cancelled)

    private var hasFirstCurveBeenCreated: Bool = false

    private(set) var tmpIterator = Iterator<GrayscaleDotPoint>()

    public var currentCurvePoints: [GrayscaleDotPoint] {
        var array: [GrayscaleDotPoint] = []

        if isFirstCurveNeeded {
            array.append(contentsOf: makeFirstCurvePoints())
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if touchPhase.value == .ended {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array
    }

    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        self.tmpIterator.append(points)
        self.touchPhase.send(touchPhase)

        self.makeSmoothCurve()
    }

    override public func reset() {
        super.reset()

        tmpIterator.reset()

        touchPhase.send(.cancelled)
        hasFirstCurveBeenCreated = false
    }
}

extension SmoothDrawingCurve {

    private var isFirstCurveNeeded: Bool {
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
