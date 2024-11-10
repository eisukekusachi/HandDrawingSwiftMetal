//
//  CanvasPencilDrawingCurvePoints.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit
/// A class that saves points in real-time to an iterator, then generates a curve based on those points.
/// - Parameters:
///   - iterator: An iterator that stores points
///   - currentTouchPhase: Manages the touch phases from the beginning to the end of drawing a single line
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

    func reset() {
        iterator.reset()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}
