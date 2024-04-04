//
//  LineDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/04.
//

import UIKit

final class LineDrawing: DrawingLineProtocol {

    let iterator: Iterator<DotPoint> = Iterator()

    var hashValue: TouchHashValue?
}

extension LineDrawing {

    func setHashValueIfNil(_ touchManager: TouchManager) {
        if hashValue == nil {
            // When a gesture is determined to be `drawing`, the touchManager manages only one finger
            hashValue = touchManager.touchPointsDictionary.keys.first
        }
    }

    func appendToIterator(
        _ points: [DotPoint]
    ) {
        iterator.append(elems: points)
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
        iterator.clear()
    }

}
