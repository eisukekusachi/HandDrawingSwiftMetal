//
//  LineDrawing.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/04.
//

import UIKit

final class LineDrawing: DrawingLineProtocol {

    var hashValue: TouchHashValue?

    let iterator: Iterator<DotPoint> = Iterator()

    func initDrawing(hashValue: TouchHashValue) {
        self.hashValue = hashValue
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

    func clearIterator() {
        hashValue = nil
        iterator.clear()
    }

}
