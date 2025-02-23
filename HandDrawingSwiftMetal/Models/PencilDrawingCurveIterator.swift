//
//  PencilDrawingCurveIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// An iterator for real-time pencil drawing with `UITouch.Phase`
final class PencilDrawingCurveIterator: Iterator<GrayscaleDotPoint>, DrawingCurveIterator {

    var currentTouchPhase: UITouch.Phase = .began

    private var isFirstCurveHasBeenCreated: Bool = false

    override func reset() {
        super.reset()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}

extension PencilDrawingCurveIterator {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !isFirstCurveHasBeenCreated

        if isFirstCurveToBeCreated {
            isFirstCurveHasBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

    func appendToIterator(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        self.append(points)
        currentTouchPhase = touchPhase
    }

}
