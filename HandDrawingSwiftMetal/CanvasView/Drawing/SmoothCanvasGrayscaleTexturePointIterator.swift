//
//  SmoothCanvasGrayscaleTexturePointIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class SmoothCanvasGrayscaleTexturePointIterator: CanvasGrayscaleTexturePointIterator {
    var iterator = Iterator<GrayscaleTexturePoint>()

    var startAfterPoint: TouchPoint?

    var currentDictionaryKey: TouchHashValue?

    private var tmpIterator = Iterator<GrayscaleTexturePoint>()

}

extension SmoothCanvasGrayscaleTexturePointIterator {

    func appendToIterator(
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

    func reset() {
        tmpIterator.clear()
        iterator.clear()

        startAfterPoint = nil
        currentDictionaryKey = nil
    }

}
