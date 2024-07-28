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

    private var startDrawing: Bool = false
    private var latestForce: CGFloat?

    func initDrawing(hashValue: TouchHashValue) {
        self.hashValue = hashValue
    }

    func appendToIterator(
        _ points: [DotPoint]
    ) {
        iterator.append(points)
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

    func setInaccurateAlphaToZero() {
        if latestForce == nil {
            latestForce = iterator.array.first?.alpha
        }

        if let latestForce {

            var index: Int = 0
            while index < iterator.array.count - 1 {
                if iterator.array[index + 1].alpha == latestForce {
                    iterator.replace(
                        index: index,
                        element: DotPoint(
                            location: iterator.array[index].location,
                            alpha: 0.0
                        )
                    )

                } else if !startDrawing && iterator.array[index].alpha != iterator.array[index + 1].alpha {
                    iterator.replace(
                        index: index,
                        element: DotPoint(
                            location: iterator.array[index].location,
                            alpha: 0.0
                        )
                    )
                    startDrawing = true
                }

                index += 1
            }
        }
    }

    func clearIterator() {
        hashValue = nil
        iterator.clear()

        latestForce = nil
        startDrawing = false
    }

}
