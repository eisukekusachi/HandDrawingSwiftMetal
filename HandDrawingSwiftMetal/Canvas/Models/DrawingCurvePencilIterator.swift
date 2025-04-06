//
//  DrawingCurvePencilIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

/// An iterator for real-time pencil drawing with `UITouch.Phase`
final class DrawingCurvePencilIterator: Iterator<GrayscaleDotPoint>, DrawingCurveIterator {

    var touchPhase: UITouch.Phase = .began

    private var hasFirstCurveBeenCreated: Bool = false

    var latestCurvePoints: [GrayscaleDotPoint] {
        var array: [GrayscaleDotPoint] = []

        if shouldGetFirstCurve {
            array.append(contentsOf: makeFirstCurvePoints())
        }

        array.append(contentsOf: makeIntermediateCurvePoints(shouldIncludeEndPoint: false))

        if isDrawingFinished {
            array.append(contentsOf: makeLastCurvePoints())
        }

        return array
    }

    func append(
        points: [GrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        self.append(points)
        self.touchPhase = touchPhase
    }

    override func reset() {
        super.reset()

        touchPhase = .began
        hasFirstCurveBeenCreated = false
    }

}

extension DrawingCurvePencilIterator {

    var shouldGetFirstCurve: Bool {
        let isFirstCurveToBeCreated = self.array.count >= 3 && !hasFirstCurveBeenCreated

        if isFirstCurveToBeCreated {
            hasFirstCurveBeenCreated = true
        }

        return isFirstCurveToBeCreated
    }

}
