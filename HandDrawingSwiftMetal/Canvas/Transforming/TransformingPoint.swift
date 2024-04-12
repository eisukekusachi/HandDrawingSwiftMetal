//
//  TransformingPoint.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import Foundation

/// A class for managing the start and last finger positions of a screen touch for canvas transforming
class TransformingPoint {

    var hashValue: TouchHashValue

    var startAndLastLocations: (CGPoint, CGPoint)? {
        guard
            let startTouchPoint,
            let lastTouchPoint
        else { return nil }

        return (
            startTouchPoint.location,
            lastTouchPoint.location
        )
    }

    private (set) var startTouchPoint: TouchPoint?
    private (set) var lastTouchPoint: TouchPoint?

    init(hashValue: TouchHashValue) {
        self.hashValue = hashValue
    }

    func updateTouchPoints(_ point: TouchPoint) {
        if startTouchPoint == nil {
            startTouchPoint = point
        } else {
            lastTouchPoint = point
        }
    }

}
