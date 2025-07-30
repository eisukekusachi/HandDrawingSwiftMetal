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

    public let touchPhase = CurrentValueSubject<UITouch.Phase, Never>(.cancelled)

    @MainActor
    public var currentCurvePoints: [GrayscaleDotPoint] {
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

    /// Returns true if `singleCurveIterator` is nil
    public static func shouldCreateInstance(drawingCurve: DrawingCurve?) -> Bool {
        drawingCurve == nil
    }

    @MainActor
    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
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

public extension SmoothDrawingCurve {

    var isFirstCurveNeeded: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !hasFirstCurveBeenCreated

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

    @MainActor
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
