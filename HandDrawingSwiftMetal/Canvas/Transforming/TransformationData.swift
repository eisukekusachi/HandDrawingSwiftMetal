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

    init(touchPointArrayDictionary: [Int: [TouchPoint]]) {
        if  touchPointArrayDictionary.count == 2,
            let pointAFirst = touchPointArrayDictionary.first?.first?.location,
            let pointALast = touchPointArrayDictionary.first?.last?.location,
            let pointBFirst = touchPointArrayDictionary.last?.first?.location,
            let pointBLast = touchPointArrayDictionary.last?.last?.location {

            pointsA = (pointAFirst, pointALast)
            pointsB = (pointBFirst, pointBLast)
        }
    }
}
