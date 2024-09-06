//
//  CanvasSmoothGrayscaleTexturePointIterator.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/28.
//

import UIKit

final class CanvasSmoothGrayscaleTexturePointIterator: CanvasGrayscaleCurveIterator {
    var iterator = Iterator<CanvasGrayscaleDotPoint>()

    private var tmpIterator = Iterator<CanvasGrayscaleDotPoint>()

}

extension CanvasSmoothGrayscaleTexturePointIterator {

    func appendToIterator(
        points: [CanvasGrayscaleDotPoint],
        touchPhase: UITouch.Phase
    ) {
        tmpIterator.append(points)

        // Add the first point.
        if (tmpIterator.array.count != 0 && iterator.array.count == 0),
           let firstElement = tmpIterator.array.first {
            iterator.append(firstElement)
        }

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = CanvasGrayscaleDotPoint.average(
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
    }

}
