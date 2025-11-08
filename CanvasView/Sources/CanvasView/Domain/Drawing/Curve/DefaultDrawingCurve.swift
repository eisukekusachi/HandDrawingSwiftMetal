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

    public let touchPhase = CurrentValueSubject<TouchPhase, Never>(.cancelled)

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

    private var hasFirstCurveBeenCreated: Bool

    public init(hasFirstCurveBeenCreated: Bool = false) {
        self.hasFirstCurveBeenCreated = hasFirstCurveBeenCreated
    }

    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
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
