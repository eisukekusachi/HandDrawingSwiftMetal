//
//  SmoothDrawingCurve.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import Combine
import UIKit

/// An iterator for creating a smooth curve in real-time using touch phases
final class SmoothDrawingCurve: Iterator<GrayscaleDotPoint>, DrawingCurve {

    var touchPhase: TouchPhase {
        _touchPhase
    }

    /// Checks whether the first curve has ever been drawn during the drawing process
    var isFirstCurveNeeded: Bool {
        return array.count >= 3 && !hasFirstCurveBeenDrawn
    }

    func markFirstCurveAsDrawn() {
        hasFirstCurveBeenDrawn = true
    }

    private var _touchPhase: TouchPhase = .cancelled

    private var hasFirstCurveBeenDrawn: Bool = false

    private var tmpIterator = Iterator<GrayscaleDotPoint>()

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        self.tmpIterator.append(points)
        self._touchPhase = touchPhase

        self.appendSmoothPoints()
    }

    override func reset() {
        super.reset()

        tmpIterator.reset()

        _touchPhase = .cancelled
        hasFirstCurveBeenDrawn = false
    }
}

extension SmoothDrawingCurve {

    private func appendSmoothPoints() {
        guard tmpIterator.array.count >= 2 else { return }

        if self.array.count == 0,
           let firstElement = tmpIterator.array.first {
            self.append(firstElement)
        }

        for window in tmpIterator.windows(ofCount: 2) {
            self.append(
                GrayscaleDotPoint.average(
                    window[0],
                    window[1]
                )
            )
        }

        if touchPhase == .ended,
            let lastElement = tmpIterator.array.last {
            self.append(lastElement)
        }
    }
}
