//
//  TransformationData.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

class TransformingData {

    var hashValue: TouchHashValue

    var touches: (CGPoint, CGPoint)? {
        guard
            let firstPoint,
            let lastPoint
        else { return nil }

        return (firstPoint, lastPoint)
    }

    private var firstPoint: CGPoint?
    private var lastPoint: CGPoint?

    init(hashValue: TouchHashValue) {
        self.hashValue = hashValue
    }

    func updatePoint(_ point: CGPoint) {
        if firstPoint == nil {
            firstPoint = point
        } else {
            lastPoint = point
        }
    }

}
