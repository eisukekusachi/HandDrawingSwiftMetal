//
//  TransformationData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

struct TransformationData {
    var pointsA: (CGPoint, CGPoint)?
    var pointsB: (CGPoint, CGPoint)?

    init(touchPoints: [Int: [TouchPoint]]) {
        if  touchPoints.count == 2,
            let pointAFirst = touchPoints.first?.first?.location,
            let pointALast = touchPoints.first?.last?.location,
            let pointBFirst = touchPoints.last?.first?.location,
            let pointBLast = touchPoints.last?.last?.location {

            pointsA = (pointAFirst, pointALast)
            pointsB = (pointBFirst, pointBLast)
        }
    }
}
