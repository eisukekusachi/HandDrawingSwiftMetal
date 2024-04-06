//
//  SmoothLineDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/06.
//

import UIKit

final class SmoothLineDrawing: DrawingLineProtocol {

    var hashValue: TouchHashValue?

    let iterator: Iterator<DotPoint> = Iterator()

    private var tmpIterator: Iterator<DotPoint> = Iterator()
}

extension SmoothLineDrawing {

    func setHashValueIfNil(_ touchManager: TouchManager) {
        if hashValue == nil {
            // When a gesture is determined to be `drawing`, the touchManager manages only one finger
            hashValue = touchManager.touchPointsDictionary.keys.first
        }
    }

    func appendToIterator(_ points: [DotPoint]) {
        tmpIterator.append(elems: points)

        // Add the first point.
        if (tmpIterator.array.count != 0 && iterator.array.count == 0),
           let firstElement = tmpIterator.array.first {
            iterator.append(elem: firstElement)
        }

        while let subsequence = tmpIterator.next(range: 2) {
            let dotPoint = DotPoint.average(lhs: subsequence[0],
                                            rhs: subsequence[1])
            iterator.append(elem: dotPoint)
        }
    }

    func appendLastTouchToSmoothCurveIterator() {
        if let lastElement = tmpIterator.array.last {
            iterator.append(elem: lastElement)
        }
    }

    func makeLineSegment(
        with parameters: LineParameters,
        phase: UITouch.Phase
    ) -> LineSegment {
        return .init(
            dotPoints: iterator.array,
            parameters: parameters,
            touchPhase: phase
        )
    }

    func clear() {
        hashValue = nil
        tmpIterator.clear()
        iterator.clear()
    }

}
