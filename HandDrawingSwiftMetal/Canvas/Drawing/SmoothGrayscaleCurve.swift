//
//  SmoothGrayscaleCurve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class SmoothGrayscaleCurve: GrayscaleCurve {

    let iterator = GrayscaleTexturePointIterator()

    var startAfterPoint: TouchPoint?

    var currentDictionaryKey: TouchHashValue?

    private var tmpIterator = GrayscaleTexturePointIterator()

    func updateIterator(
        points: [GrayscaleTexturePoint],
        touchPhase: UITouch.Phase
    ) -> [GrayscaleTexturePoint] {

        appendToIterator(
            points: points,
            touchPhase: touchPhase
        )

        return makeCurvePointsFromIterator(
            touchPhase: touchPhase
        )
    }

    func reset() {
        tmpIterator.clear()
        iterator.clear()

        startAfterPoint = nil
        currentDictionaryKey = nil
    }

}

extension SmoothGrayscaleCurve {

    private func appendToIterator(
        points: [GrayscaleTexturePoint],
        touchPhase: UITouch.Phase
    ) {
        tmpIterator.append(points)

        // Add the first point.
        if (tmpIterator.array.count != 0 && iterator.array.count == 0),
           let firstElement = tmpIterator.array.first {
            iterator.append(firstElement)
        }

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = GrayscaleTexturePoint.average(
                subsequence[0],
                subsequence[1]
            )
            iterator.append(dotPoint)
        }

        if touchPhase == .ended,
            let lastElement = tmpIterator.array.last {
            iterator.append(lastElement)
        }
    }

    private func makeCurvePointsFromIterator(
        touchPhase: UITouch.Phase
    ) -> [GrayscaleTexturePoint] {
        iterator.makeCurvePoints(atEnd: touchPhase == .ended)
    }

}
