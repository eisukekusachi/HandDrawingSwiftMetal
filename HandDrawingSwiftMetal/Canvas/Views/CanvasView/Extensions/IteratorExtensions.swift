//
//  IteratorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import Foundation

extension Iterator<GrayscaleDotPoint> {

    func getBezierCurveFirstPoints() -> BezierCurveFirstPoints? {
        guard array.count >= 3 else { return nil }
        return .init(
            previousPoint: array[0],
            startPoint: array[1],
            endPoint: array[2]
        )
    }

    func getBezierCurveIntermediatePointsWithFixedRange4() -> [BezierCurveIntermediatePoints] {
        var array: [BezierCurveIntermediatePoints] = []
        while let subsequence = next(range: 4) {
            array.append(
                .init(
                    previousPoint: subsequence[0],
                    startPoint: subsequence[1],
                    endPoint: subsequence[2],
                    nextPoint: subsequence[3]
                )
            )
        }
        return array
    }

    func getBezierCurveLastPoints() -> BezierCurveLastPoints? {
        guard array.count >= 3 else { return nil }
        return .init(
            previousPoint: array[array.count - 3],
            startPoint: array[array.count - 2],
            endPoint: array[array.count - 1]
        )
    }

}
