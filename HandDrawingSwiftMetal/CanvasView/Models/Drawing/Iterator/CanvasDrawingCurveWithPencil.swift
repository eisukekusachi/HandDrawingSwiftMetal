//
//  CanvasDrawingCurveWithPencil.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class CanvasDrawingCurveWithPencil: CanvasDrawingCurve {
    var iterator = Iterator<CanvasGrayscaleDotPoint>()

    var currentTouchPhase: UITouch.Phase = .began

    private var isFirstCurveHasBeenCreated: Bool = false
}

extension CanvasDrawingCurveWithPencil {

    /// Returns `true` if three elements are added to the array and `isFirstCurveHasBeenCreated` is `false`
    var hasArrayThreeElementsButNoFirstCurveCreated: Bool {
        iterator.array.count >= 3 && !isFirstCurveHasBeenCreated
    }

    func appendToIterator(
        points: [CanvasGrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        iterator.append(points)
        currentTouchPhase = touchPhase
    }

    func makeCurvePointsFromIterator() -> [CanvasGrayscaleDotPoint]? {
        var array: [CanvasGrayscaleDotPoint] = []

        if hasArrayThreeElementsButNoFirstCurveCreated {
            array.append(contentsOf: makeFirstCurvePoints())
            isFirstCurveHasBeenCreated = true
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingComplete {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array.count != 0 ? array : nil
    }

    func clear() {
        iterator.clear()

        currentTouchPhase = .began
        isFirstCurveHasBeenCreated = false
    }

}
