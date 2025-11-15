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

    private var hasFirstCurveBeenDrawn: Bool = false

    private var tmpIterator = Iterator<GrayscaleDotPoint>()

    public func append(
        points: [GrayscaleDotPoint],
        touchPhase: TouchPhase
    ) {
        self.tmpIterator.append(points)
        self._touchPhase = touchPhase

        self.appendSmoothPoints()
    }

    override public func reset() {
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

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = GrayscaleDotPoint.average(
                subsequence[0],
                subsequence[1]
            )
            self.append(dotPoint)
        }

        if touchPhase == .ended,
            let lastElement = tmpIterator.array.last {
            self.append(lastElement)
        }
    }
}
