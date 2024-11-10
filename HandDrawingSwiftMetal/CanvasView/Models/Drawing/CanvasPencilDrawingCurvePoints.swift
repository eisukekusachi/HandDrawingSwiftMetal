//
//  CanvasPencilDrawingCurvePoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// Manages real-time curve drawing using an iterator and touch phases
final class CanvasPencilDrawingCurvePoints: CanvasDrawingCurvePoints {
    var iterator = Iterator<CanvasGrayscaleDotPoint>()

    var currentTouchPhase: UITouch.Phase = .began

    private var isFirstCurveHasBeenCreated: Bool = false
}

extension CanvasPencilDrawingCurvePoints {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        let isFirstCurveToBeCreated = iterator.array.count >= 3 && !isFirstCurveHasBeenCreated
        
        if isFirstCurveToBeCreated {
            isFirstCurveHasBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

    func appendToIterator(
        points: [CanvasGrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        iterator.append(points)
        currentTouchPhase = touchPhase
    }

    func clear() {
        iterator.clear()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}
