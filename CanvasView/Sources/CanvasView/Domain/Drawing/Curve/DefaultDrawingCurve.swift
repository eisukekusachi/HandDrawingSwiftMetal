//
//  DefaultDrawingCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// iterator for creating a curve in real-time using touch phases
public final class DefaultDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

    public var touchPhase: TouchPhase {
        _touchPhase
    }

    /// Checks whether the first curve has ever been drawn during the drawing process
    public func isFirstCurveNeeded() -> Bool {
        return array.count >= 3 && !hasFirstCurveBeenDrawn
    }

    public func markFirstCurveAsDrawn() {
        hasFirstCurveBeenDrawn = true
    }

    private var _touchPhase: TouchPhase = .cancelled

    private(set) var hasFirstCurveBeenDrawn: Bool = false

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
