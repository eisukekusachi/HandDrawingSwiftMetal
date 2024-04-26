//
//  Curve.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/31.
//

import Foundation

enum Curve {

    static func makePoints(
        from iterator: Iterator<DotPoint>,
        isFinishDrawing: Bool = false
    ) -> [DotPoint] {

        var curve: [DotPoint] = []

        while let subsequence = iterator.next(range: 4) {

            if iterator.isFirstProcessing {
                let points = Curve.makeFirstPoints(iterator: iterator)
                curve.append(contentsOf: points)
            }

            let points = DotPoint.makeCurve(
                previousPoint: subsequence[0],
                startPoint: subsequence[1],
                endPoint: subsequence[2],
                nextPoint: subsequence[3])

            curve.append(contentsOf: points)
        }

        if isFinishDrawing {
            if iterator.index == 0 {
                let points = Curve.makeFirstPoints(iterator: iterator)
                curve.append(contentsOf: points)
            }

            let points = Curve.makeLastPoints(iterator: iterator)
            curve.append(contentsOf: points)
        }

        return curve
    }

    static private func makeFirstPoints(iterator: Iterator<DotPoint>) -> [DotPoint] {
        guard iterator.array.count >= 3 else { return [] }

        let index0 = 0
        let index1 = 1
        let index2 = 2

        return DotPoint.makeFirstCurve(
            previousPoint: iterator.array[index0],
            startPoint: iterator.array[index1],
            endPoint: iterator.array[index2],
            addLastPoint: false)
    }

    static private func makeLastPoints(iterator: Iterator<DotPoint>) -> [DotPoint] {
        guard iterator.array.count >= 3 else { return [] }

        let index0 = iterator.array.count - 3
        let index1 = iterator.array.count - 2
        let index2 = iterator.array.count - 1

        return DotPoint.makeLastCurve(
            startPoint: iterator.array[index0],
            endPoint: iterator.array[index1],
            nextPoint: iterator.array[index2],
            addLastPoint: true)
    }

}
