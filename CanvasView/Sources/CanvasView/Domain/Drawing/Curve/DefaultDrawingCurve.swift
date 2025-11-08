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

    public var touchPhase: TouchPhase {
        _touchPhase
    }

    public func isFirstCurveNeeded() -> Bool {
        let isFirstCurveToBeCreated = array.count >= 3 && !hasFirstCurveBeenDrawn

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenDrawn = true
        }

        return isFirstCurveToBeCreated
    }

    private var _touchPhase: TouchPhase = .cancelled

    private var hasFirstCurveBeenDrawn: Bool = false

    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        self.append(points)
        self._touchPhase = touchPhase
    }

    override public func reset() {
        super.reset()

        _touchPhase = .cancelled
        hasFirstCurveBeenDrawn = false
    }
}
