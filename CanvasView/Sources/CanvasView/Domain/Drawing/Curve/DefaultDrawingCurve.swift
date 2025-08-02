//
//  DefaultDrawingCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// An iterator for creating a curve in real-time using touch phases
public final class DefaultDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

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

    private var hasFirstCurveBeenCreated: Bool

    // Even if `singleCurveIterator` already exists, it will be replaced with a new `PencilSingleCurveIterator`
    // whenever a touch with `.began` phase is detected, since pencil input takes precedence.
    public static func shouldCreateInstance(actualTouches: Set<UITouch>) -> Bool {
        actualTouches.contains(where: { $0.phase == .began })
    }

    public init(hasFirstCurveBeenCreated: Bool = false) {
        self.hasFirstCurveBeenCreated = hasFirstCurveBeenCreated
    }

    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        self.append(points)
        self.touchPhase.send(touchPhase)
    }

    override public func reset() {
        super.reset()

        touchPhase.send(.cancelled)
        hasFirstCurveBeenCreated = false
    }
}

public extension DefaultDrawingCurve {

    var isFirstCurveNeeded: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !hasFirstCurveBeenCreated

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }
}
