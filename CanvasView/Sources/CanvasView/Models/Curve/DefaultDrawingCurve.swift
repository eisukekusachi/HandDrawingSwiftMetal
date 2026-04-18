//
//  DefaultDrawingCurve.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// iterator for creating a curve in real-time using touch phases
final class DefaultDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

    var touchPhase: TouchPhase {
        _touchPhase
    }

    /// Checks whether the first curve has ever been drawn during the drawing process
    func isFirstCurveNeeded() -> Bool {
        return array.count >= 3 && !hasFirstCurveBeenDrawn
    }

    func markFirstCurveAsDrawn() {
        hasFirstCurveBeenDrawn = true
    }

    private var _touchPhase: TouchPhase = .cancelled

    private(set) var hasFirstCurveBeenDrawn: Bool = false

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        self.append(points)
        self._touchPhase = touchPhase
    }

    override func reset() {
        super.reset()

        _touchPhase = .cancelled
        hasFirstCurveBeenDrawn = false
    }
}
